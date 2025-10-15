use starknet::ContractAddress;

// Vault configuration struct
#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct VaultConfig {
    pub asset: ContractAddress,
    pub strategy_manager: ContractAddress,
    pub vesu_adapter: ContractAddress,
    pub troves_adapter: ContractAddress,
    pub performance_fee_bps: u32,
    pub management_fee_bps: u32,
    pub fee_recipient: ContractAddress,
    pub max_vesu_weight_bps: u32,
    pub max_troves_weight_bps: u32,
}

#[starknet::interface]
pub trait IBitYieldVault<TContractState> {
    fn deposit(ref self: TContractState, assets: u256) -> u256;
    fn withdraw(ref self: TContractState, shares: u256) -> u256;
    fn total_assets(self: @TContractState) -> u256;
    fn convert_to_shares(self: @TContractState, assets: u256) -> u256;
    fn convert_to_assets(self: @TContractState, shares: u256) -> u256;
    fn rebalance(ref self: TContractState, vesu_target_bps: u32, troves_target_bps: u32);
    fn collect_fees(ref self: TContractState);
    fn emergency_withdraw(ref self: TContractState);
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn update_strategy(ref self: TContractState, strategy_type: felt252, new_address: ContractAddress);
    fn update_fees(ref self: TContractState, performance_fee_bps: u32, management_fee_bps: u32);
    fn get_config(self: @TContractState) -> VaultConfig;
}

#[starknet::contract]
mod BitYieldVault {
    use super::VaultConfig;
    use starknet::{ContractAddress, get_contract_address, get_caller_address, get_block_timestamp};
    use core::num::traits::Zero;
    use openzeppelin_token::erc20::{ERC20Component, interface::{IERC20Dispatcher, IERC20DispatcherTrait}};
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_security::pausable::PausableComponent;
    use openzeppelin_security::reentrancyguard::ReentrancyGuardComponent;
    use openzeppelin_upgrades::upgradeable::UpgradeableComponent;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry
    };

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: ReentrancyGuardComponent, storage: reentrancy, event: ReentrancyEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    // Implement ImmutableConfig for ERC20
  impl ERC20ImmutableConfig of ERC20Component::ImmutableConfig {
    const DECIMALS: u8 = 8_u8;  // WBTC uses 8 decimals
}

    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    impl ReentrancyInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    // Implement ERC20 Hooks (required by OpenZeppelin)
    impl ERC20HooksImpl of ERC20Component::ERC20HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            // Custom logic before transfer (if needed)
        }

        fn after_update(
            ref self: ERC20Component::ComponentState<ContractState>,
            from: ContractAddress,
            recipient: ContractAddress,
            amount: u256
        ) {
            // Custom logic after transfer (if needed)
        }
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        pausable: PausableComponent::Storage,
        #[substorage(v0)]
        reentrancy: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        asset: ContractAddress,
        total_assets_deposited: u256,
        strategy_manager: ContractAddress,
        vesu_adapter: ContractAddress,
        troves_adapter: ContractAddress,
        performance_fee_bps: u32,
        management_fee_bps: u32,
        fee_recipient: ContractAddress,
        last_fee_collection: u64,
        max_vesu_weight_bps: u32,
        max_troves_weight_bps: u32,
        user_deposits: Map<ContractAddress, u256>,
        total_shares: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        PausableEvent: PausableComponent::Event,
        #[flat]
        ReentrancyEvent: ReentrancyGuardComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        Deposit: Deposit,
        Withdraw: Withdraw,
        Rebalance: Rebalance,
        FeeCollected: FeeCollected,
        StrategyUpdated: StrategyUpdated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Deposit {
        #[key]
        pub user: ContractAddress,
        pub assets: u256,
        pub shares: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Withdraw {
        #[key]
        pub user: ContractAddress,
        pub assets: u256,
        pub shares: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Rebalance {
        pub vesu_allocation: u256,
        pub troves_allocation: u256,
        pub total_assets: u256,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct FeeCollected {
        pub performance_fee: u256,
        pub management_fee: u256,
        #[key]
        pub recipient: ContractAddress,
        pub timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StrategyUpdated {
        #[key]
        pub strategy_type: felt252,
        pub old_address: ContractAddress,
        pub new_address: ContractAddress,
    }

    // Error constants
    pub const ZERO_ADDRESS: felt252 = 'Zero address not allowed';
    pub const ZERO_AMOUNT: felt252 = 'Amount must be greater than 0';
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
    pub const INSUFFICIENT_SHARES: felt252 = 'Insufficient shares';
    pub const MAX_WEIGHT_EXCEEDED: felt252 = 'Max allocation weight exceeded';
    pub const INVALID_FEE: felt252 = 'Invalid fee percentage';
    pub const TRANSFER_FAILED: felt252 = 'Token transfer failed';
    pub const INVALID_STRATEGY_TYPE: felt252 = 'Invalid strategy type';

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        asset: ContractAddress,
        strategy_manager: ContractAddress,
        vesu_adapter: ContractAddress,
        troves_adapter: ContractAddress,
        fee_recipient: ContractAddress,
    ) {
        self.erc20.initializer("BitYield WBTC Vault", "byWBTC");
        self.ownable.initializer(owner);
        
        self.asset.write(asset);
        self.strategy_manager.write(strategy_manager);
        self.vesu_adapter.write(vesu_adapter);
        self.troves_adapter.write(troves_adapter);
        self.fee_recipient.write(fee_recipient);
        
        // Set default fees (1% performance, 0.5% management annually)
        self.performance_fee_bps.write(100);
        self.management_fee_bps.write(50);
        
        // Set default allocation limits (70% Vesu, 30% Troves)
        self.max_vesu_weight_bps.write(7000);
        self.max_troves_weight_bps.write(3000);
        
        self.last_fee_collection.write(get_block_timestamp());
        self.total_assets_deposited.write(0);
        self.total_shares.write(0);
    }

    #[abi(embed_v0)]
    impl BitYieldVaultImpl of super::IBitYieldVault<ContractState> {
        fn deposit(ref self: ContractState, assets: u256) -> u256 {
            self.pausable.assert_not_paused();
            self.reentrancy.start();
            
            assert!(assets > 0, "{}", ZERO_AMOUNT);
            let caller = get_caller_address();
            let this = get_contract_address();
            
            // Transfer WBTC from user to vault
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            let success = asset_token.transfer_from(caller, this, assets);
            assert!(success, "{}", TRANSFER_FAILED);
            
            // Calculate shares to mint (1:1 ratio for first deposit)
            let shares = self._convert_to_shares(assets);
            
            // Mint byWBTC shares to user
            self.erc20.mint(caller, shares);
            
            // Update state
            let current_deposits = self.user_deposits.entry(caller).read();
            self.user_deposits.entry(caller).write(current_deposits + assets);
            
            let current_total = self.total_assets_deposited.read();
            self.total_assets_deposited.write(current_total + assets);
            
            let current_shares = self.total_shares.read();
            self.total_shares.write(current_shares + shares);
            
            self.emit(Deposit {
                user: caller,
                assets,
                shares,
                timestamp: get_block_timestamp(),
            });
            
            self.reentrancy.end();
            shares
        }

        fn withdraw(ref self: ContractState, shares: u256) -> u256 {
            self.pausable.assert_not_paused();
            self.reentrancy.start();
            
            assert!(shares > 0, "{}", ZERO_AMOUNT);
            let caller = get_caller_address();
            
            // Check user has enough shares
            let user_balance = self.erc20.balance_of(caller);
            assert!(user_balance >= shares, "{}", INSUFFICIENT_SHARES);
            
            // Calculate assets to return
            let assets = self._convert_to_assets(shares);
            
            // Withdraw from strategies if needed
            self._ensure_liquidity(assets);
            
            // Burn shares
            self.erc20.burn(caller, shares);
            
            // Transfer WBTC to user
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            let success = asset_token.transfer(caller, assets);
            assert!(success, "{}", TRANSFER_FAILED);
            
            // Update state
            let current_total = self.total_assets_deposited.read();
            self.total_assets_deposited.write(current_total - assets);
            
            let current_shares = self.total_shares.read();
            self.total_shares.write(current_shares - shares);
            
            self.emit(Withdraw {
                user: caller,
                assets,
                shares,
                timestamp: get_block_timestamp(),
            });
            
            self.reentrancy.end();
            assets
        }

        fn total_assets(self: @ContractState) -> u256 {
            let idle_assets = self._get_idle_balance();
            let vesu_assets = self._get_vesu_balance();
            let troves_assets = self._get_troves_balance();
            
            idle_assets + vesu_assets + troves_assets
        }

        fn convert_to_shares(self: @ContractState, assets: u256) -> u256 {
            self._convert_to_shares(assets)
        }

        fn convert_to_assets(self: @ContractState, shares: u256) -> u256 {
            self._convert_to_assets(shares)
        }

        fn rebalance(ref self: ContractState, vesu_target_bps: u32, troves_target_bps: u32) {
            self.ownable.assert_only_owner();
            self.pausable.assert_not_paused();
            
            // Validate allocations
            assert!(vesu_target_bps <= self.max_vesu_weight_bps.read(), "{}", MAX_WEIGHT_EXCEEDED);
            assert!(troves_target_bps <= self.max_troves_weight_bps.read(), "{}", MAX_WEIGHT_EXCEEDED);
            assert!(vesu_target_bps + troves_target_bps <= 10000, "{}", MAX_WEIGHT_EXCEEDED);
            
            // Collect fees before rebalancing
            self._collect_fees();
            
            let total = self.total_assets();
            let vesu_target = (total * vesu_target_bps.into()) / 10000;
            let troves_target = (total * troves_target_bps.into()) / 10000;
            
            // Execute rebalancing through strategy manager
            self._execute_rebalance(vesu_target, troves_target);
            
            self.emit(Rebalance {
                vesu_allocation: vesu_target,
                troves_allocation: troves_target,
                total_assets: total,
                timestamp: get_block_timestamp(),
            });
        }

        fn collect_fees(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self._collect_fees();
        }

        fn emergency_withdraw(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self._emergency_withdraw_all();
        }

        fn pause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.pause();
        }

        fn unpause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.unpause();
        }

        fn update_strategy(ref self: ContractState, strategy_type: felt252, new_address: ContractAddress) {
            self.ownable.assert_only_owner();
            assert!(!new_address.is_zero(), "{}", ZERO_ADDRESS);
            
            let (old_address, valid_type) = if strategy_type == 'vesu' {
                let old = self.vesu_adapter.read();
                self.vesu_adapter.write(new_address);
                (old, true)
            } else if strategy_type == 'troves' {
                let old = self.troves_adapter.read();
                self.troves_adapter.write(new_address);
                (old, true)
            } else {
                (Zero::zero(), false)
            };
            
            assert!(valid_type, "{}", INVALID_STRATEGY_TYPE);
            
            self.emit(StrategyUpdated {
                strategy_type,
                old_address,
                new_address,
            });
        }

        fn update_fees(ref self: ContractState, performance_fee_bps: u32, management_fee_bps: u32) {
            self.ownable.assert_only_owner();
            assert!(performance_fee_bps <= 2000, "{}", INVALID_FEE);  // Max 20%
            assert!(management_fee_bps <= 500, "{}", INVALID_FEE);  // Max 5%
            
            self.performance_fee_bps.write(performance_fee_bps);
            self.management_fee_bps.write(management_fee_bps);
        }

        fn get_config(self: @ContractState) -> VaultConfig {
            VaultConfig {
                asset: self.asset.read(),
                strategy_manager: self.strategy_manager.read(),
                vesu_adapter: self.vesu_adapter.read(),
                troves_adapter: self.troves_adapter.read(),
                performance_fee_bps: self.performance_fee_bps.read(),
                management_fee_bps: self.management_fee_bps.read(),
                fee_recipient: self.fee_recipient.read(),
                max_vesu_weight_bps: self.max_vesu_weight_bps.read(),
                max_troves_weight_bps: self.max_troves_weight_bps.read(),
            }
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _convert_to_shares(self: @ContractState, assets: u256) -> u256 {
            let total_supply = self.total_shares.read();
            if total_supply == 0 {
                assets  // 1:1 ratio for first deposit
            } else {
                let total = self.total_assets();
                if total == 0 {
                    assets
                } else {
                    (assets * total_supply) / total
                }
            }
        }

        fn _convert_to_assets(self: @ContractState, shares: u256) -> u256 {
            let total_supply = self.total_shares.read();
            if total_supply == 0 {
                0
            } else {
                (shares * self.total_assets()) / total_supply
            }
        }

        fn _get_idle_balance(self: @ContractState) -> u256 {
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            asset_token.balance_of(get_contract_address())
        }

        fn _get_vesu_balance(self: @ContractState) -> u256 {
            // TODO: Call Vesu adapter to get deposited amount
            0  // Placeholder
        }

        fn _get_troves_balance(self: @ContractState) -> u256 {
            // TODO: Call Troves adapter to get deposited amount
            0  // Placeholder
        }

        fn _ensure_liquidity(ref self: ContractState, amount_needed: u256) {
            let idle = self._get_idle_balance();
            if idle >= amount_needed {
                return;
            }
            
            // TODO: Withdraw from strategies as needed
            let _deficit = amount_needed - idle;
            // Implement withdrawal logic from Vesu/Troves
        }

        fn _execute_rebalance(ref self: ContractState, _vesu_target: u256, _troves_target: u256) {
            // TODO: Implementation depends on strategy manager and adapter interfaces
        }

        fn _collect_fees(ref self: ContractState) {
            let current_time = get_block_timestamp();
            let last_collection = self.last_fee_collection.read();
            let time_elapsed = current_time - last_collection;
            
            if time_elapsed == 0 {
                return;
            }
            
            // Calculate management fee (annual rate prorated)
            let total = self.total_assets();
            let annual_mgmt_fee = (total * self.management_fee_bps.read().into()) / 10000;
            let mgmt_fee = (annual_mgmt_fee * time_elapsed.into()) / 31536000; // seconds in year
            
            // Performance fee calculated on gains
            // Simplified: would need to track high water mark
            
            if mgmt_fee > 0 {
                let fee_recipient = self.fee_recipient.read();
                let fee_shares = self._convert_to_shares(mgmt_fee);
                self.erc20.mint(fee_recipient, fee_shares);
                
                self.emit(FeeCollected {
                    performance_fee: 0,
                    management_fee: mgmt_fee,
                    recipient: fee_recipient,
                    timestamp: current_time,
                });
            }
            
            self.last_fee_collection.write(current_time);
        }

  fn _emergency_withdraw_all(ref self: ContractState) {
            
        }


       
    }
}
