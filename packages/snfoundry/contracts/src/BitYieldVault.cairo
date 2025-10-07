#[starknet::contract]
mod BitYieldVault {
    use starknet::{ContractAddress, get_contract_address, get_caller_address, get_block_timestamp};
    use openzeppelin::token::erc20::{ERC20Component, interface::{IERC20Dispatcher, IERC20DispatcherTrait}};
    use openzeppelin::access::ownable::{OwnableComponent};
    use openzeppelin::security::pausable::{PausableComponent};
    use openzeppelin::security::reentrancyguard::{ReentrancyGuardComponent};
    use openzeppelin::upgrades::upgradeable::{UpgradeableComponent};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: PausableComponent, storage: pausable, event: PausableEvent);
    component!(path: ReentrancyGuardComponent, storage: reentrancy, event: ReentrancyEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl ERC20Impl = ERC20Component::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;
    impl PausableInternalImpl = PausableComponent::InternalImpl<ContractState>;
    impl ReentrancyInternalImpl = ReentrancyGuardComponent::InternalImpl<ContractState>;

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
        
        // Core vault state
        asset: ContractAddress,  // WBTC token address
        total_assets_deposited: u256,
        
        // Strategy configuration
        strategy_manager: ContractAddress,
        vesu_adapter: ContractAddress,
        troves_adapter: ContractAddress,
        
        // Fee configuration
        performance_fee_bps: u32,  // basis points (1% = 100 bps)
        management_fee_bps: u32,
        fee_recipient: ContractAddress,
        last_fee_collection: u64,
        
        // Pool allocation limits
        max_vesu_weight_bps: u32,  // max % allocation to Vesu
        max_troves_weight_bps: u32,  // max % allocation to Troves
        
        // User tracking
        user_deposits: LegacyMap<ContractAddress, u256>,
        total_shares: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
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
    struct Deposit {
        #[key]
        user: ContractAddress,
        assets: u256,
        shares: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        #[key]
        user: ContractAddress,
        assets: u256,
        shares: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct Rebalance {
        vesu_allocation: u256,
        troves_allocation: u256,
        total_assets: u256,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct FeeCollected {
        performance_fee: u256,
        management_fee: u256,
        recipient: ContractAddress,
        timestamp: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct StrategyUpdated {
        strategy_type: felt252,
        old_address: ContractAddress,
        new_address: ContractAddress,
    }

    mod Errors {
        const ZERO_ADDRESS: felt252 = 'Zero address not allowed';
        const ZERO_AMOUNT: felt252 = 'Amount must be greater than 0';
        const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
        const INSUFFICIENT_SHARES: felt252 = 'Insufficient shares';
        const MAX_WEIGHT_EXCEEDED: felt252 = 'Max allocation weight exceeded';
        const INVALID_FEE: felt252 = 'Invalid fee percentage';
        const TRANSFER_FAILED: felt252 = 'Token transfer failed';
    }

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
    }

    #[abi(embed_v0)]
    impl BitYieldVaultImpl of super::IBitYieldVault<ContractState> {
        /// Deposit WBTC into the vault and receive byWBTC shares
        fn deposit(ref self: ContractState, assets: u256) -> u256 {
            self.pausable.assert_not_paused();
            self.reentrancy.start();
            
            assert(assets > 0, Errors::ZERO_AMOUNT);
            let caller = get_caller_address();
            let this = get_contract_address();
            
            // Transfer WBTC from user to vault
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            let success = asset_token.transfer_from(caller, this, assets);
            assert(success, Errors::TRANSFER_FAILED);
            
            // Calculate shares to mint (1:1 ratio for first deposit)
            let shares = self._convert_to_shares(assets);
            
            // Mint byWBTC shares to user
            self.erc20.mint(caller, shares);
            
            // Update state
            let current_deposits = self.user_deposits.read(caller);
            self.user_deposits.write(caller, current_deposits + assets);
            self.total_assets_deposited.write(self.total_assets_deposited.read() + assets);
            self.total_shares.write(self.total_shares.read() + shares);
            
            self.emit(Deposit {
                user: caller,
                assets,
                shares,
                timestamp: get_block_timestamp(),
            });
            
            self.reentrancy.end();
            shares
        }

        /// Withdraw WBTC by burning byWBTC shares
        fn withdraw(ref self: ContractState, shares: u256) -> u256 {
            self.pausable.assert_not_paused();
            self.reentrancy.start();
            
            assert(shares > 0, Errors::ZERO_AMOUNT);
            let caller = get_caller_address();
            
            // Check user has enough shares
            let user_balance = self.erc20.balance_of(caller);
            assert(user_balance >= shares, Errors::INSUFFICIENT_SHARES);
            
            // Calculate assets to return
            let assets = self._convert_to_assets(shares);
            
            // Withdraw from strategies if needed
            self._ensure_liquidity(assets);
            
            // Burn shares
            self.erc20.burn(caller, shares);
            
            // Transfer WBTC to user
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            let success = asset_token.transfer(caller, assets);
            assert(success, Errors::TRANSFER_FAILED);
            
            // Update state
            self.total_assets_deposited.write(self.total_assets_deposited.read() - assets);
            self.total_shares.write(self.total_shares.read() - shares);
            
            self.emit(Withdraw {
                user: caller,
                assets,
                shares,
                timestamp: get_block_timestamp(),
            });
            
            self.reentrancy.end();
            assets
        }

        /// Get total assets under management
        fn total_assets(self: @ContractState) -> u256 {
            let idle_assets = self._get_idle_balance();
            let vesu_assets = self._get_vesu_balance();
            let troves_assets = self._get_troves_balance();
            
            idle_assets + vesu_assets + troves_assets
        }

        /// Convert assets to shares
        fn convert_to_shares(self: @ContractState, assets: u256) -> u256 {
            self._convert_to_shares(assets)
        }

        /// Convert shares to assets
        fn convert_to_assets(self: @ContractState, shares: u256) -> u256 {
            self._convert_to_assets(shares)
        }

        /// Rebalance assets across strategies
        fn rebalance(ref self: ContractState, vesu_target_bps: u32, troves_target_bps: u32) {
            self.ownable.assert_only_owner();
            self.pausable.assert_not_paused();
            
            // Validate allocations
            assert(vesu_target_bps <= self.max_vesu_weight_bps.read(), Errors::MAX_WEIGHT_EXCEEDED);
            assert(troves_target_bps <= self.max_troves_weight_bps.read(), Errors::MAX_WEIGHT_EXCEEDED);
            assert(vesu_target_bps + troves_target_bps <= 10000, Errors::MAX_WEIGHT_EXCEEDED);
            
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

        /// Collect performance and management fees
        fn collect_fees(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self._collect_fees();
        }

        /// Emergency withdrawal - pull all funds from strategies
        fn emergency_withdraw(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self._emergency_withdraw_all();
        }

        /// Pause deposits and withdrawals
        fn pause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.pause();
        }

        /// Unpause deposits and withdrawals
        fn unpause(ref self: ContractState) {
            self.ownable.assert_only_owner();
            self.pausable.unpause();
        }

        /// Update strategy adapter addresses
        fn update_strategy(ref self: ContractState, strategy_type: felt252, new_address: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(!new_address.is_zero(), Errors::ZERO_ADDRESS);
            
            let old_address = if strategy_type == 'vesu' {
                let old = self.vesu_adapter.read();
                self.vesu_adapter.write(new_address);
                old
            } else if strategy_type == 'troves' {
                let old = self.troves_adapter.read();
                self.troves_adapter.write(new_address);
                old
            } else {
                panic_with_felt252('Invalid strategy type');
                starknet::contract_address_const::<0>()
            };
            
            self.emit(StrategyUpdated {
                strategy_type,
                old_address,
                new_address,
            });
        }

        /// Update fee configuration
        fn update_fees(ref self: ContractState, performance_fee_bps: u32, management_fee_bps: u32) {
            self.ownable.assert_only_owner();
            assert(performance_fee_bps <= 2000, Errors::INVALID_FEE);  // Max 20%
            assert(management_fee_bps <= 500, Errors::INVALID_FEE);  // Max 5%
            
            self.performance_fee_bps.write(performance_fee_bps);
            self.management_fee_bps.write(management_fee_bps);
        }

        /// Get vault configuration
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
            // Call Vesu adapter to get deposited amount
            // Implementation depends on Vesu adapter interface
            0  // Placeholder
        }

        fn _get_troves_balance(self: @ContractState) -> u256 {
            // Call Troves adapter to get deposited amount
            0  // Placeholder
        }

        fn _ensure_liquidity(ref self: ContractState, amount_needed: u256) {
            let idle = self._get_idle_balance();
            if idle >= amount_needed {
                return;
            }
            
            // Withdraw from strategies as needed
            let deficit = amount_needed - idle;
            // Implement withdrawal logic from Vesu/Troves
        }

        fn _execute_rebalance(ref self: ContractState, vesu_target: u256, troves_target: u256) {
            // Implementation depends on strategy manager and adapter interfaces
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
            // Withdraw everything from all strategies
            // Implementation depends on adapter interfaces
        }
    }
}

#[starknet::interface]
trait IBitYieldVault<TContractState> {
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

#[derive(Drop, Serde, starknet::Store)]
struct VaultConfig {
    asset: ContractAddress,
    strategy_manager: ContractAddress,
    vesu_adapter: ContractAddress,
    troves_adapter: ContractAddress,
    performance_fee_bps: u32,
    management_fee_bps: u32,
    fee_recipient: ContractAddress,
    max_vesu_weight_bps: u32,
    max_troves_weight_bps: u32,
}