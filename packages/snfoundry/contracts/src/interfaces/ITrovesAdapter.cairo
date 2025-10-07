use starknet::ContractAddress;

#[starknet::interface]
pub trait ITrovesAdapter<TContractState> {
    // Strategy management
    fn add_strategy(ref self: TContractState, strategy_address: ContractAddress, weight: u32);
    fn remove_strategy(ref self: TContractState, strategy_id: u32);
    
    // Deposit/Withdraw operations
    fn deposit(ref self: TContractState, strategy_id: u32, assets: u256) -> u256;
    fn withdraw(ref self: TContractState, strategy_id: u32, assets: u256) -> u256;
    
    // Yield operations
    fn harvest_rewards(ref self: TContractState, strategy_id: u32) -> u256;
    
    // View functions
    fn get_total_assets(self: @TContractState) -> u256;
    fn get_strategy_balance(self: @TContractState, strategy_id: u32) -> u256;
    fn get_active_strategies(self: @TContractState) -> Array<u32>;
    
    // Configuration
    fn update_troves_addresses(
        ref self: TContractState,
        strategy_manager: ContractAddress,
        liquid_staking: ContractAddress
    );
}