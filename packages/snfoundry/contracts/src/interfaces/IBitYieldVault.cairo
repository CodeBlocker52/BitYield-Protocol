use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
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
    // ERC20 functions
    // fn name(self: @TContractState) -> ByteArray;
    // fn symbol(self: @TContractState) -> ByteArray;
    // fn decimals(self: @TContractState) -> u8;
    fn total_supply(self: @TContractState) -> u256;
    // fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    // fn allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
    // fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256) -> bool;
    // fn transfer_from(
    //     ref self: TContractState,
    //     sender: ContractAddress,
    //     recipient: ContractAddress,
    //     amount: u256
    // ) -> bool;
    // fn approve(ref self: TContractState, spender: ContractAddress, amount: u256) -> bool;

    // ERC4626 functions
    fn asset(self: @TContractState) -> ContractAddress;
    fn total_assets(self: @TContractState) -> u256;
    fn convert_to_shares(self: @TContractState, assets: u256) -> u256;
    fn convert_to_assets(self: @TContractState, shares: u256) -> u256;
    fn max_deposit(self: @TContractState, receiver: ContractAddress) -> u256;
    fn preview_deposit(self: @TContractState, assets: u256) -> u256;
    fn max_mint(self: @TContractState, receiver: ContractAddress) -> u256;
    fn preview_mint(self: @TContractState, shares: u256) -> u256;
    fn max_withdraw(self: @TContractState, owner: ContractAddress) -> u256;
    fn preview_withdraw(self: @TContractState, assets: u256) -> u256;
    fn max_redeem(self: @TContractState, owner: ContractAddress) -> u256;
    fn preview_redeem(self: @TContractState, shares: u256) -> u256;

    // Vault specific functions
    fn deposit(ref self: TContractState, assets: u256) -> u256;
    fn mint(ref self: TContractState, shares: u256) -> u256;
    fn withdraw(ref self: TContractState, shares: u256) -> u256;
    fn redeem(ref self: TContractState, shares: u256) -> u256;
    fn rebalance(ref self: TContractState, vesu_target_bps: u32, troves_target_bps: u32);
    fn collect_fees(ref self: TContractState);
    fn emergency_withdraw(ref self: TContractState);
    fn pause(ref self: TContractState);
    fn unpause(ref self: TContractState);
    fn update_strategy(ref self: TContractState, strategy_type: felt252, new_address: ContractAddress);
    fn update_fees(ref self: TContractState, performance_fee_bps: u32, management_fee_bps: u32);
    fn get_config(self: @TContractState) -> VaultConfig;

    // Ownable functions
    fn owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TContractState);
}