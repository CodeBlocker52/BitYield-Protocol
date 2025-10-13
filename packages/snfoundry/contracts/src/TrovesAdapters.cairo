use starknet::ContractAddress;

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
    use starknet::{ContractAddress, get_contract_address, get_caller_address};
    use core::num::traits::Zero;
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher};
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
    pub const NOT_IMPLEMENTED: felt252 = 'Function not yet implemented';

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
            
            // TODO: Implement actual Troves deposit logic when contracts are available
            // Example flow:
            // 1. Transfer assets from vault to this adapter
            // 2. Approve Troves contract to spend assets
            // 3. Call Troves deposit function
            // 4. Track deposited amount
            
            // Placeholder implementation
            let _vault = self.vault.read();
            let _this = get_contract_address();
            let _asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            
            // Transfer from vault (would need approval first)
            // asset_token.transfer_from(vault, this, assets);
            
            let current_total = self.total_assets_in_strategies.read();
            self.total_assets_in_strategies.write(current_total + assets);
            
            self.emit(Deposited { strategy_id, assets });
            
            assets // Return shares or receipt tokens
        }

        fn withdraw(ref self: ContractState, strategy_id: u32, assets: u256) -> u256 {
            self._assert_vault_caller();
            assert!(assets > 0, "{}", ZERO_AMOUNT);
            
            let config = self.active_strategies.entry(strategy_id).read();
            assert!(config.is_active, "{}", STRATEGY_INACTIVE);
            
            // TODO: Implement actual Troves withdrawal logic
            // Example flow:
            // 1. Call Troves withdraw function
            // 2. Receive assets back to adapter
            // 3. Transfer assets to vault
            // 4. Update tracked amounts
            
            // Placeholder implementation
            let _vault = self.vault.read();
            let _asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            
            // Transfer to vault
            // asset_token.transfer(vault, assets);
            
            let current_total = self.total_assets_in_strategies.read();
            self.total_assets_in_strategies.write(current_total - assets);
            
            self.emit(Withdrawn { strategy_id, assets });
            
            assets
        }

        fn harvest_rewards(ref self: ContractState, strategy_id: u32) -> u256 {
            self.ownable.assert_only_owner();
            
            let config = self.active_strategies.entry(strategy_id).read();
            assert!(config.is_active, "{}", STRATEGY_INACTIVE);
            
            // TODO: Implement reward harvesting
            // Example flow:
            // 1. Call Troves claim_rewards
            // 2. Swap rewards to WBTC (if needed)
            // 3. Compound back into strategy or return to vault
            
            let reward_amount: u256 = 0; // Placeholder
            
            self.emit(RewardsHarvested { strategy_id, reward_amount });
            
            reward_amount
        }

        fn get_total_assets(self: @ContractState) -> u256 {
            // TODO: Query actual balances from Troves contracts
            self.total_assets_in_strategies.read()
        }

        fn get_strategy_balance(self: @ContractState, strategy_id: u32) -> u256 {
            let config = self.active_strategies.entry(strategy_id).read();
            if !config.is_active {
                return 0;
            }
            
            // TODO: Query actual balance from Troves contract
            0 // Placeholder
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
    }
}