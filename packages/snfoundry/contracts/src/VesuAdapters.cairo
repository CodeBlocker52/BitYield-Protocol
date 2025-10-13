use starknet::ContractAddress;

#[starknet::interface]
pub trait IVesuAdapter<TContractState> {
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

#[starknet::interface]
pub trait IVesuVToken<TContractState> {
    fn asset(self: @TContractState) -> ContractAddress;
    fn total_assets(self: @TContractState) -> u256;
    fn convert_to_shares(self: @TContractState, assets: u256) -> u256;
    fn convert_to_assets(self: @TContractState, shares: u256) -> u256;
    fn deposit(ref self: TContractState, assets: u256, receiver: ContractAddress) -> u256;
    fn withdraw(
        ref self: TContractState,
        assets: u256,
        receiver: ContractAddress,
        owner: ContractAddress
    ) -> u256;
    fn max_withdraw(self: @TContractState, owner: ContractAddress) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
}

#[starknet::contract]
mod VesuAdapter {
    use super::{IVesuVTokenDispatcher, IVesuVTokenDispatcherTrait};
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

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        vesu_v_tokens: Map<felt252, ContractAddress>,
        active_pool_ids: Map<u32, felt252>,
        pool_count: u32,
        vault: ContractAddress,
        asset: ContractAddress,
        total_shares: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        PoolAdded: PoolAdded,
        PoolRemoved: PoolRemoved,
        Deposited: Deposited,
        Withdrawn: Withdrawn,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PoolAdded {
        #[key]
        pub pool_id: felt252,
        pub v_token: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct PoolRemoved {
        #[key]
        pub pool_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Deposited {
        #[key]
        pub pool_id: felt252,
        pub assets: u256,
        pub shares: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Withdrawn {
        #[key]
        pub pool_id: felt252,
        pub assets: u256,
        pub shares: u256,
    }

    // Error messages as constants
    pub const UNAUTHORIZED: felt252 = 'Only vault can call';
    pub const POOL_NOT_FOUND: felt252 = 'Pool not found';
    pub const POOL_EXISTS: felt252 = 'Pool already exists';
    pub const ZERO_ADDRESS: felt252 = 'Zero address not allowed';
    pub const ZERO_AMOUNT: felt252 = 'Amount must be greater than 0';
    pub const INSUFFICIENT_BALANCE: felt252 = 'Insufficient balance';
    pub const TRANSFER_FAILED: felt252 = 'Transfer failed';

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
        self.pool_count.write(0);
        self.total_shares.write(0);
    }

    #[abi(embed_v0)]
    impl VesuAdapterImpl of super::IVesuAdapter<ContractState> {
        fn add_pool(ref self: ContractState, pool_id: felt252, v_token: ContractAddress) {
            self.ownable.assert_only_owner();
            assert!(!v_token.is_zero(), "{}", ZERO_ADDRESS);
            
            let existing_v_token = self.vesu_v_tokens.entry(pool_id).read();
            assert!(existing_v_token.is_zero(), "{}", POOL_EXISTS);
            
            self.vesu_v_tokens.entry(pool_id).write(v_token);
            let index = self.pool_count.read();
            self.active_pool_ids.entry(index).write(pool_id);
            self.pool_count.write(index + 1);
            
            // Approve v_token to spend asset (max approval)
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            let max_approval: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
            asset_token.approve(v_token, max_approval);
            
            self.emit(PoolAdded { pool_id, v_token });
        }

        fn remove_pool(ref self: ContractState, pool_id: felt252) {
            self.ownable.assert_only_owner();
            let v_token = self.vesu_v_tokens.entry(pool_id).read();
            assert!(!v_token.is_zero(), "{}", POOL_NOT_FOUND);
            
            // Ensure no assets in this pool
            let balance = self._get_pool_balance(pool_id);
            assert!(balance == 0, "{}", INSUFFICIENT_BALANCE);
            
            self.vesu_v_tokens.entry(pool_id).write(Zero::zero());
            self.emit(PoolRemoved { pool_id });
        }

        fn deposit(ref self: ContractState, pool_id: felt252, assets: u256) -> u256 {
            self._assert_vault_caller();
            assert!(assets > 0, "{}", ZERO_AMOUNT);
            
            let v_token_address = self.vesu_v_tokens.entry(pool_id).read();
            assert!(!v_token_address.is_zero(), "{}", POOL_NOT_FOUND);
            
            let vault = self.vault.read();
            let this = get_contract_address();
            
            // Transfer assets from vault to this adapter
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            let success = asset_token.transfer_from(vault, this, assets);
            assert!(success, "{}", TRANSFER_FAILED);
            
            // Deposit into Vesu vToken
            let v_token = IVesuVTokenDispatcher { contract_address: v_token_address };
            let shares = v_token.deposit(assets, this);
            
            let current_total = self.total_shares.read();
            self.total_shares.write(current_total + shares);
            
            self.emit(Deposited { pool_id, assets, shares });
            shares
        }

        fn withdraw(ref self: ContractState, pool_id: felt252, assets: u256) -> u256 {
            self._assert_vault_caller();
            assert!(assets > 0, "{}", ZERO_AMOUNT);
            
            let v_token_address = self.vesu_v_tokens.entry(pool_id).read();
            assert!(!v_token_address.is_zero(), "{}", POOL_NOT_FOUND);
            
            let vault = self.vault.read();
            let this = get_contract_address();
            
            // Withdraw from Vesu vToken
            let v_token = IVesuVTokenDispatcher { contract_address: v_token_address };
            let shares = v_token.withdraw(assets, vault, this);
            
            let current_total = self.total_shares.read();
            self.total_shares.write(current_total - shares);
            
            self.emit(Withdrawn { pool_id, assets, shares });
            shares
        }

        fn withdraw_all(ref self: ContractState, pool_id: felt252) -> u256 {
            self._assert_vault_caller();
            
            let v_token_address = self.vesu_v_tokens.entry(pool_id).read();
            assert!(!v_token_address.is_zero(), "{}", POOL_NOT_FOUND);
            
            let this = get_contract_address();
            let vault = self.vault.read();
            
            let v_token = IVesuVTokenDispatcher { contract_address: v_token_address };
            let max_withdraw = v_token.max_withdraw(this);
            
            if max_withdraw == 0 {
                return 0;
            }
            
            let shares = v_token.withdraw(max_withdraw, vault, this);
            let current_total = self.total_shares.read();
            self.total_shares.write(current_total - shares);
            
            self.emit(Withdrawn { pool_id, assets: max_withdraw, shares });
            max_withdraw
        }

        fn get_total_assets(self: @ContractState) -> u256 {
            let mut total: u256 = 0;
            let count = self.pool_count.read();
            
            let mut i: u32 = 0;
            while i < count {
                let pool_id = self.active_pool_ids.entry(i).read();
                let v_token = self.vesu_v_tokens.entry(pool_id).read();
                
                if !v_token.is_zero() {
                    total += self._get_pool_balance(pool_id);
                }
                
                i += 1;
            };
            
            total
        }

        fn get_pool_balance(self: @ContractState, pool_id: felt252) -> u256 {
            self._get_pool_balance(pool_id)
        }

        fn get_active_pools(self: @ContractState) -> Array<felt252> {
            let mut pools: Array<felt252> = ArrayTrait::new();
            let count = self.pool_count.read();
            
            let mut i: u32 = 0;
            while i < count {
                let pool_id = self.active_pool_ids.entry(i).read();
                let v_token = self.vesu_v_tokens.entry(pool_id).read();
                
                if !v_token.is_zero() {
                    pools.append(pool_id);
                }
                
                i += 1;
            };
            
            pools
        }

        fn get_v_token(self: @ContractState, pool_id: felt252) -> ContractAddress {
            self.vesu_v_tokens.entry(pool_id).read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _assert_vault_caller(self: @ContractState) {
            let caller = get_caller_address();
            let vault = self.vault.read();
            assert!(caller == vault, "{}", UNAUTHORIZED);
        }

        fn _get_pool_balance(self: @ContractState, pool_id: felt252) -> u256 {
            let v_token_address = self.vesu_v_tokens.entry(pool_id).read();
            if v_token_address.is_zero() {
                return 0;
            }
            
            let this = get_contract_address();
            let v_token = IVesuVTokenDispatcher { contract_address: v_token_address };
            let shares = v_token.balance_of(this);
            
            if shares == 0 {
                0
            } else {
                v_token.convert_to_assets(shares)
            }
        }
    }
}