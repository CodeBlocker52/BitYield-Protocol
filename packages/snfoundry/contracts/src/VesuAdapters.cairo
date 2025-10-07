#[starknet::contract]
mod VesuAdapter {
    use starknet::{ContractAddress, get_contract_address, get_caller_address};
    use openzeppelin::access::ownable::{OwnableComponent};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    // Vesu Protocol Interfaces (based on provided contracts)
    #[starknet::interface]
    trait IERC4626<TContractState> {
        fn asset(self: @TContractState) -> ContractAddress;
        fn total_assets(self: @TContractState) -> u256;
        fn convert_to_shares(self: @TContractState, assets: u256) -> u256;
        fn convert_to_assets(self: @TContractState, shares: u256) -> u256;
        fn deposit(ref self: TContractState, assets: u256, receiver: ContractAddress) -> u256;
        fn withdraw(ref self: TContractState, assets: u256, receiver: ContractAddress, owner: ContractAddress) -> u256;
        fn max_withdraw(self: @TContractState, owner: ContractAddress) -> u256;
        fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        
        // Vesu VToken addresses for WBTC pools
        vesu_v_tokens: LegacyMap<felt252, ContractAddress>,  // pool_id -> v_token
        active_pool_ids: LegacyMap<u32, felt252>,  // index -> pool_id
        pool_count: u32,
        
        // Vault address that can call this adapter
        vault: ContractAddress,
        
        // Asset being managed (WBTC)
        asset: ContractAddress,
        
        // Total shares held across all pools
        total_shares: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        
        PoolAdded: PoolAdded,
        PoolRemoved: PoolRemoved,
        Deposited: Deposited,
        Withdrawn: Withdrawn,
    }

    #[derive(Drop, starknet::Event)]
    struct PoolAdded {
        pool_id: felt252,
        v_token: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct PoolRemoved {
        pool_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct Deposited {
        pool_id: felt252,
        assets: u256,
        shares: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct Withdrawn {
        pool_id: felt252,
        assets: u256,
        shares: u256,
    }

    mod Errors {
        const UNAUTHORIZED: felt252 = 'Only vault can call';
        const POOL_NOT_FOUND: felt252 = 'Pool not found';
        const POOL_EXISTS: felt252 = 'Pool already exists';
        const ZERO_ADDRESS: felt252 = 'Zero address not allowed';
        const ZERO_AMOUNT: felt252 = 'Amount must be greater than 0';
        const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
        const TRANSFER_FAILED: felt252 = 'Transfer failed';
    }

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
    }

    #[abi(embed_v0)]
    impl VesuAdapterImpl of super::IVesuAdapter<ContractState> {
        /// Add a new Vesu pool for deposits
        fn add_pool(ref self: ContractState, pool_id: felt252, v_token: ContractAddress) {
            self.ownable.assert_only_owner();
            assert(!v_token.is_zero(), Errors::ZERO_ADDRESS);
            assert(self.vesu_v_tokens.read(pool_id).is_zero(), Errors::POOL_EXISTS);
            
            self.vesu_v_tokens.write(pool_id, v_token);
            let index = self.pool_count.read();
            self.active_pool_ids.write(index, pool_id);
            self.pool_count.write(index + 1);
            
            // Approve v_token to spend asset
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            asset_token.approve(v_token, 0x035c58475afe0f44fa5267ffee18facd535ae5bb64085035369d07ce2b3afb4d); // Max approval
            
            self.emit(PoolAdded { pool_id, v_token });
        }

        /// Remove a Vesu pool (must be empty)
        fn remove_pool(ref self: ContractState, pool_id: felt252) {
            self.ownable.assert_only_owner();
            let v_token = self.vesu_v_tokens.read(pool_id);
            assert(!v_token.is_zero(), Errors::POOL_NOT_FOUND);
            
            // Ensure no assets in this pool
            let balance = self._get_pool_balance(pool_id);
            assert(balance == 0, Errors::INSUFFICIENT_BALANCE);
            
            self.vesu_v_tokens.write(pool_id, starknet::contract_address_const::<0>());
            self.emit(PoolRemoved { pool_id });
        }

        /// Deposit assets into a specific Vesu pool
        fn deposit(ref self: ContractState, pool_id: felt252, assets: u256) -> u256 {
            self._assert_vault_caller();
            assert(assets > 0, Errors::ZERO_AMOUNT);
            
            let v_token_address = self.vesu_v_tokens.read(pool_id);
            assert(!v_token_address.is_zero(), Errors::POOL_NOT_FOUND);
            
            let vault = self.vault.read();
            let this = get_contract_address();
            
            // Transfer assets from vault to this adapter
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            let success = asset_token.transfer_from(vault, this, assets);
            assert(success, Errors::TRANSFER_FAILED);
            
            // Deposit into Vesu vToken
            let v_token = IERC4626Dispatcher { contract_address: v_token_address };
            let shares = v_token.deposit(assets, this);
            
            self.total_shares.write(self.total_shares.read() + shares);
            
            self.emit(Deposited { pool_id, assets, shares });
            shares
        }

        /// Withdraw assets from a specific Vesu pool
        fn withdraw(ref self: ContractState, pool_id: felt252, assets: u256) -> u256 {
            self._assert_vault_caller();
            assert(assets > 0, Errors::ZERO_AMOUNT);
            
            let v_token_address = self.vesu_v_tokens.read(pool_id);
            assert(!v_token_address.is_zero(), Errors::POOL_NOT_FOUND);
            
            let vault = self.vault.read();
            let this = get_contract_address();
            
            // Withdraw from Vesu vToken
            let v_token = IERC4626Dispatcher { contract_address: v_token_address };
            let shares = v_token.withdraw(assets, vault, this);
            
            self.total_shares.write(self.total_shares.read() - shares);
            
            self.emit(Withdrawn { pool_id, assets, shares });
            shares
        }

        /// Withdraw all assets from a specific pool (emergency)
        fn withdraw_all(ref self: ContractState, pool_id: felt252) -> u256 {
            self._assert_vault_caller();
            
            let v_token_address = self.vesu_v_tokens.read(pool_id);
            assert(!v_token_address.is_zero(), Errors::POOL_NOT_FOUND);
            
            let this = get_contract_address();
            let vault = self.vault.read();
            
            let v_token = IERC4626Dispatcher { contract_address: v_token_address };
            let max_withdraw = v_token.max_withdraw(this);
            
            if max_withdraw == 0 {
                return 0;
            }
            
            let shares = v_token.withdraw(max_withdraw, vault, this);
            self.total_shares.write(self.total_shares.read() - shares);
            
            self.emit(Withdrawn { pool_id, assets: max_withdraw, shares });
            max_withdraw
        }

        /// Get total assets deposited across all Vesu pools
        fn get_total_assets(self: @ContractState) -> u256 {
            let mut total: u256 = 0;
            let count = self.pool_count.read();
            
            let mut i: u32 = 0;
            loop {
                if i >= count {
                    break;
                }
                
                let pool_id = self.active_pool_ids.read(i);
                if !self.vesu_v_tokens.read(pool_id).is_zero() {
                    total += self._get_pool_balance(pool_id);
                }
                
                i += 1;
            };
            
            total
        }

        /// Get assets deposited in a specific pool
        fn get_pool_balance(self: @ContractState, pool_id: felt252) -> u256 {
            self._get_pool_balance(pool_id)
        }

        /// Get all active pool IDs
        fn get_active_pools(self: @ContractState) -> Array<felt252> {
            let mut pools: Array<felt252> = ArrayTrait::new();
            let count = self.pool_count.read();
            
            let mut i: u32 = 0;
            loop {
                if i >= count {
                    break;
                }
                
                let pool_id = self.active_pool_ids.read(i);
                if !self.vesu_v_tokens.read(pool_id).is_zero() {
                    pools.append(pool_id);
                }
                
                i += 1;
            };
            
            pools
        }

        /// Get the vToken address for a pool
        fn get_v_token(self: @ContractState, pool_id: felt252) -> ContractAddress {
            self.vesu_v_tokens.read(pool_id)
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_vault_caller(self: @ContractState) {
            assert(get_caller_address() == self.vault.read(), Errors::UNAUTHORIZED);
        }

        fn _get_pool_balance(self: @ContractState, pool_id: felt252) -> u256 {
            let v_token_address = self.vesu_v_tokens.read(pool_id);
            if v_token_address.is_zero() {
                return 0;
            }
            
            let this = get_contract_address();
            let v_token = IERC4626Dispatcher { contract_address: v_token_address };
            let shares = v_token.balance_of(this);
            
            if shares == 0 {
                0
            } else {
                v_token.convert_to_assets(shares)
            }
        }
    }
}

#[starknet::interface]
trait IVesuAdapter<TContractState> {
    fn add_pool(ref self: TContractState, pool_id: felt252, v_token: ContractAddress);
    fn remove_pool(ref self: TContractState, pool_id: felt252);
    fn deposit(ref self: TContractState, pool_id: felt252, assets: u256) -> u256;
    fn withdraw(ref self: TContractState, pool_id: felt252, assets: u256) -> u256;
    fn withdraw_all(ref self: TContractState, pool_id: felt252) -> u256;
    fn get_total_assets(self: @TContractState) -> u256;
    fn get_pool_balance(self: @TContractState, pool_id: felt252) -> u256;
    fn get_active_pools(self: @TContractState) -> Array<felt252>;
    fn get_v_token(self: @TContractState, pool_id: felt252) -> ContractAddress;
}