use starknet::ContractAddress;

#[starknet::interface]
pub trait ITrovesStrategy<TContractState> {
    fn deposit(ref self: TContractState, assets: u256) -> u256;
    fn withdraw(ref self: TContractState, shares: u256, receiver: ContractAddress) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn total_assets(self: @TContractState) -> u256;
}

#[starknet::interface]
pub trait ITrovesAdapter<TContractState> {
    fn add_strategy(ref self: TContractState, strategy_address: ContractAddress, weight: u32);
    fn remove_strategy(ref self: TContractState, strategy_id: u32);
    fn deposit(ref self: TContractState, strategy_id: u32, assets: u256) -> u256;
    fn withdraw(ref self: TContractState, strategy_id: u32, assets: u256) -> u256;
    fn harvest_rewards(ref self: TContractState, strategy_id: u32) -> u256;
    fn get_total_assets(self: @TContractState) -> u256;
    fn get_strategy_balance(self: @TContractState, strategy_id: u32) -> u256;
    fn get_active_strategies(self: @TContractState) -> Array<u32>;
    fn update_troves_addresses(
        ref self: TContractState,
        strategy_manager: ContractAddress,
        liquid_staking: ContractAddress
    );
}

#[starknet::contract]
mod TrovesAdapter {
    use super::{ITrovesStrategyDispatcher, ITrovesStrategyDispatcherTrait};
    use starknet::{ContractAddress, get_contract_address, get_caller_address};
    use core::num::traits::Zero;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry
    };

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[derive(Drop, Copy, Serde, starknet::Store)]
    pub struct StrategyConfig {
        pub strategy_address: ContractAddress,
        pub is_active: bool,
        pub allocation_weight: u32,
        pub last_harvest: u64,
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        vault: ContractAddress,
        asset: ContractAddress,
        troves_strategy_manager: ContractAddress,
        troves_liquid_staking: ContractAddress,
        total_assets_in_strategies: u256,
        active_strategies: Map<u32, StrategyConfig>,
        strategy_count: u32,
        strategy_shares: Map<u32, u256>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        StrategyAdded: StrategyAdded,
        StrategyRemoved: StrategyRemoved,
        Deposited: Deposited,
        Withdrawn: Withdrawn,
        RewardsHarvested: RewardsHarvested,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StrategyAdded {
        #[key]
        pub strategy_id: u32,
        pub strategy_address: ContractAddress,
        pub weight: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StrategyRemoved {
        #[key]
        pub strategy_id: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Deposited {
        #[key]
        pub strategy_id: u32,
        pub assets: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Withdrawn {
        #[key]
        pub strategy_id: u32,
        pub assets: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct RewardsHarvested {
        #[key]
        pub strategy_id: u32,
        pub reward_amount: u256,
    }

    // Error constants
    pub const UNAUTHORIZED: felt252 = 'Only vault can call';
    pub const STRATEGY_NOT_FOUND: felt252 = 'Strategy not found';
    pub const STRATEGY_INACTIVE: felt252 = 'Strategy is inactive';
    pub const ZERO_ADDRESS: felt252 = 'Zero address not allowed';
    pub const ZERO_AMOUNT: felt252 = 'Amount must be greater than 0';

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        vault: ContractAddress,
        asset: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.vault.write(vault);
        self.asset.write(asset);
        self.strategy_count.write(0);
        self.total_assets_in_strategies.write(0);
    }

    #[abi(embed_v0)]
    impl TrovesAdapterImpl of super::ITrovesAdapter<ContractState> {
        fn add_strategy(
            ref self: ContractState,
            strategy_address: ContractAddress,
            weight: u32,
        ) {
            self.ownable.assert_only_owner();
            assert!(!strategy_address.is_zero(), "{}", ZERO_ADDRESS);
            
            let strategy_id = self.strategy_count.read();
            let config = StrategyConfig {
                strategy_address,
                is_active: true,
                allocation_weight: weight,
                last_harvest: 0,
            };
            
            self.active_strategies.entry(strategy_id).write(config);
            self.strategy_count.write(strategy_id + 1);
            
            // Approve strategy to spend asset tokens
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            let max_approval: u256 =
                0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
            asset_token.approve(strategy_address, max_approval);
            
            self.emit(StrategyAdded { strategy_id, strategy_address, weight });
        }

        fn remove_strategy(ref self: ContractState, strategy_id: u32) {
            self.ownable.assert_only_owner();
            
            let mut config = self.active_strategies.entry(strategy_id).read();
            assert!(config.is_active, "{}", STRATEGY_NOT_FOUND);
            
            config.is_active = false;
            self.active_strategies.entry(strategy_id).write(config);
            
            self.emit(StrategyRemoved { strategy_id });
        }

        fn deposit(ref self: ContractState, strategy_id: u32, assets: u256) -> u256 {
            self._assert_vault_caller();
            assert!(assets > 0, "{}", ZERO_AMOUNT);
            
            let config = self.active_strategies.entry(strategy_id).read();
            assert!(config.is_active, "{}", STRATEGY_INACTIVE);
            
            let vault = self.vault.read();
            let this = get_contract_address();
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            
            // 1. Transfer assets from vault to adapter
            asset_token.transfer_from(vault, this, assets);
            
            // 2. Deposit into Troves strategy (adapter already approved in add_strategy)
            let strategy = ITrovesStrategyDispatcher {
                contract_address: config.strategy_address
            };
            let shares = strategy.deposit(assets);
            
            // 3. Track shares received
            let current_shares = self.strategy_shares.entry(strategy_id).read();
            self.strategy_shares.entry(strategy_id).write(current_shares + shares);
            
            // 4. Update total assets
            let current_total = self.total_assets_in_strategies.read();
            self.total_assets_in_strategies.write(current_total + assets);
            
            self.emit(Deposited { strategy_id, assets });
            
            shares
        }

        fn withdraw(ref self: ContractState, strategy_id: u32, assets: u256) -> u256 {
            self._assert_vault_caller();
            assert!(assets > 0, "{}", ZERO_AMOUNT);
            
            let config = self.active_strategies.entry(strategy_id).read();
            assert!(config.is_active, "{}", STRATEGY_INACTIVE);
            
            let vault = self.vault.read();
            
            // 1. Calculate shares needed for requested assets
            let strategy = ITrovesStrategyDispatcher {
                contract_address: config.strategy_address
            };
            let total_assets = strategy.total_assets();
            let this = get_contract_address();
            let total_shares = strategy.balance_of(this);
            
            let shares_to_withdraw = if total_assets == 0 {
                0
            } else {
                (assets * total_shares) / total_assets
            };
            
            // 2. Withdraw from Troves strategy (sends assets directly to vault)
            let actual_assets = strategy.withdraw(shares_to_withdraw, vault);
            
            // 3. Update tracked shares
            let current_shares = self.strategy_shares.entry(strategy_id).read();
            if shares_to_withdraw <= current_shares {
                self.strategy_shares.entry(strategy_id).write(current_shares - shares_to_withdraw);
            } else {
                self.strategy_shares.entry(strategy_id).write(0);
            }
            
            // 4. Update total assets
            let current_total = self.total_assets_in_strategies.read();
            if actual_assets <= current_total {
                self.total_assets_in_strategies.write(current_total - actual_assets);
            } else {
                self.total_assets_in_strategies.write(0);
            }
            
            self.emit(Withdrawn { strategy_id, assets: actual_assets });
            
            actual_assets
        }

        fn harvest_rewards(ref self: ContractState, strategy_id: u32) -> u256 {
            self.ownable.assert_only_owner();
            
            let config = self.active_strategies.entry(strategy_id).read();
            assert!(config.is_active, "{}", STRATEGY_INACTIVE);
            
            // Query current balance to see yield growth
            let this = get_contract_address();
            let strategy = ITrovesStrategyDispatcher {
                contract_address: config.strategy_address
            };
            
            let shares = strategy.balance_of(this);
            if shares == 0 {
                return 0;
            }
            
            // Calculate total value including yield
            let total_strategy_assets = strategy.total_assets();
            let our_shares = shares;
            let total_shares_in_strategy = shares; 
            
            let current_value = if total_shares_in_strategy == 0 {
                0
            } else {
                (our_shares * total_strategy_assets) / total_shares_in_strategy
            };
            
            // Calculate yield earned 
            let tracked_total = self.total_assets_in_strategies.read();
            let yield_earned = if current_value > tracked_total {
                current_value - tracked_total
            } else {
                0
            };
            
            // Update tracked total to include yield
            if yield_earned > 0 {
                self.total_assets_in_strategies.write(current_value);
            }
            
            self.emit(RewardsHarvested { strategy_id, reward_amount: yield_earned });
            
            yield_earned
        }

        fn get_total_assets(self: @ContractState) -> u256 {
            let mut total: u256 = 0;
            let count = self.strategy_count.read();
            
            let mut i: u32 = 0;
            while i < count {
                let config = self.active_strategies.entry(i).read();
                if config.is_active {
                    total += self._get_strategy_balance(i);
                }
                i += 1;
            };
            
            total
        }

        fn get_strategy_balance(self: @ContractState, strategy_id: u32) -> u256 {
            self._get_strategy_balance(strategy_id)
        }

        fn get_active_strategies(self: @ContractState) -> Array<u32> {
            let mut strategies: Array<u32> = ArrayTrait::new();
            let count = self.strategy_count.read();
            
            let mut i: u32 = 0;
            while i < count {
                let config = self.active_strategies.entry(i).read();
                if config.is_active {
                    strategies.append(i);
                }
                
                i += 1;
            };
            
            strategies
        }

        fn update_troves_addresses(
            ref self: ContractState,
            strategy_manager: ContractAddress,
            liquid_staking: ContractAddress,
        ) {
            self.ownable.assert_only_owner();
            self.troves_strategy_manager.write(strategy_manager);
            self.troves_liquid_staking.write(liquid_staking);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_vault_caller(self: @ContractState) {
            let caller = get_caller_address();
            let vault = self.vault.read();
            assert!(caller == vault, "{}", UNAUTHORIZED);
        }

        fn _get_strategy_balance(self: @ContractState, strategy_id: u32) -> u256 {
            let config = self.active_strategies.entry(strategy_id).read();
            if !config.is_active {
                return 0;
            }
            
            let this = get_contract_address();
            let strategy = ITrovesStrategyDispatcher {
                contract_address: config.strategy_address
            };
            
            let shares = strategy.balance_of(this);
            if shares == 0 {
                return 0;
            }
            
            // Calculate asset value of shares
            let total_strategy_assets = strategy.total_assets();
            let total_shares = shares; 
            
            if total_shares == 0 {
                0
            } else {
                (shares * total_strategy_assets) / total_shares
            }
        }
    }
}