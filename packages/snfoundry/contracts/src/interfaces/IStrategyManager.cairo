use starknet::ContractAddress;

#[derive(Drop, Copy, Serde, starknet::Store)]
pub struct StrategyPerformance {
    pub total_deposited: u256,
    pub total_withdrawn: u256,
    pub yield_earned: u256,
    pub last_apy: u32,
    pub last_update: u64,
}

#[derive(Drop, Serde)]
pub struct RebalanceAction {
    pub from_strategy: felt252,
    pub to_strategy: felt252,
    pub amount: u256,
}

#[starknet::interface]
pub trait IStrategyManager<TContractState> {
    // Strategy operations
    fn calculate_optimal_allocation(self: @TContractState, total_assets: u256) -> (u256, u256, u256);
    fn needs_rebalance(self: @TContractState, total_assets: u256) -> bool;
    fn rebalance(ref self: TContractState, total_assets: u256) -> Array<RebalanceAction>;
    
    // Yield operations
    fn harvest_yield(ref self: TContractState) -> u256;
    
    // Configuration
    fn update_targets(ref self: TContractState, vesu_bps: u32, troves_bps: u32, idle_bps: u32);
    fn set_rebalancer(ref self: TContractState, rebalancer: ContractAddress, authorized: bool);
    fn update_rebalance_config(ref self: TContractState, threshold_bps: u32, min_interval: u64);
    
    // View functions
    fn get_targets(self: @TContractState) -> (u32, u32, u32);
    fn get_strategy_performance(self: @TContractState, strategy: felt252) -> StrategyPerformance;
    fn get_cumulative_yield(self: @TContractState) -> u256;
    fn calculate_apy(self: @TContractState) -> u32;
}