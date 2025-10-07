use starknet::ContractAddress;

#[derive(Drop, Copy, Serde, starknet::Store, PartialEq)]
pub enum BridgeStatus {
    Pending,
    Confirmed,
    Completed,
    Failed,
}

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct BridgeRequest {
    pub user: ContractAddress,
    pub btc_amount: u256,
    pub wbtc_amount: u256,
    pub status: BridgeStatus,
    pub timestamp: u64,
    pub auto_deposit: bool,
}

#[starknet::interface]
pub trait IAtomiqBridge<TContractState> {
    // Bridge operations
    fn initiate_bridge(
        ref self: TContractState,
        btc_tx_hash: felt252,
        btc_amount: u256,
        auto_deposit: bool
    );
    fn complete_bridge(ref self: TContractState, btc_tx_hash: felt252, wbtc_amount: u256);
    fn initiate_withdrawal(ref self: TContractState, wbtc_amount: u256, btc_address: ByteArray);
    
    // User settings
    fn set_auto_deposit(ref self: TContractState, enabled: bool);
    
    // View functions
    fn get_bridge_request(self: @TContractState, tx_hash: felt252) -> BridgeRequest;
    fn get_pending_deposit(self: @TContractState, user: ContractAddress) -> u256;
    fn is_auto_deposit_enabled(self: @TContractState, user: ContractAddress) -> bool;
    fn get_bridge_config(self: @TContractState) -> (u256, u256, u32);
    
    // Configuration (owner only)
    fn update_atomiq_addresses(
        ref self: TContractState,
        gateway: ContractAddress,
        router: ContractAddress
    );
    fn update_bridge_config(
        ref self: TContractState,
        min_amount: u256,
        max_amount: u256,
        fee_bps: u32
    );
}