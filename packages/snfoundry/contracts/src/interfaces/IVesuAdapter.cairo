use starknet::ContractAddress;

#[starknet::interface]
pub trait IVesuAdapter<TContractState> {
    // Pool management
    fn add_pool(ref self: TContractState, pool_id: felt252, v_token: ContractAddress);
    fn remove_pool(ref self: TContractState, pool_id: felt252);
    
    // Deposit/Withdraw operations
    fn deposit(ref self: TContractState, pool_id: felt252, assets: u256) -> u256;
    fn withdraw(ref self: TContractState, pool_id: felt252, assets: u256) -> u256;
    fn withdraw_all(ref self: TContractState, pool_id: felt252) -> u256;
    
    // View functions
    fn get_total_assets(self: @TContractState) -> u256;
    fn get_pool_balance(self: @TContractState, pool_id: felt252) -> u256;
    fn get_active_pools(self: @TContractState) -> Array<felt252>;
    fn get_v_token(self: @TContractState, pool_id: felt252) -> ContractAddress;
}

// Vesu VToken ERC4626 Interface
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