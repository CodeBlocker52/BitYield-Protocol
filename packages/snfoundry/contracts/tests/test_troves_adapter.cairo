use starknet::ContractAddress;
use core::num::traits::Zero;

use snforge_std_deprecated::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address
};

use bityield_contracts::interfaces::ITrovesAdapter::{
    ITrovesAdapterDispatcher, ITrovesAdapterDispatcherTrait, ITrovesAdapterSafeDispatcher,
    ITrovesAdapterSafeDispatcherTrait
};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

// Test constants
fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

fn VAULT() -> ContractAddress {
    'VAULT'.try_into().unwrap()
}

fn USER1() -> ContractAddress {
    'USER1'.try_into().unwrap()
}

fn STRATEGY_1() -> ContractAddress {
    'STRATEGY_1'.try_into().unwrap()
}

fn STRATEGY_2() -> ContractAddress {
    'STRATEGY_2'.try_into().unwrap()
}

fn INITIAL_SUPPLY() -> u256 {
    1000000_u256 * 100000000_u256
}

fn DEPOSIT_AMOUNT() -> u256 {
    100_u256 * 100000000_u256
}

// Deploy mock WBTC
fn deploy_mock_wbtc() -> ContractAddress {
    let contract = declare("MockWBTC").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    OWNER().serialize(ref calldata);
    INITIAL_SUPPLY().serialize(ref calldata);
    
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

// Deploy TrovesAdapter
fn deploy_troves_adapter(
    owner: ContractAddress, vault: ContractAddress, asset: ContractAddress
) -> ContractAddress {
    let contract = declare("TrovesAdapter").unwrap().contract_class();
    
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref calldata);
    vault.serialize(ref calldata);
    asset.serialize(ref calldata);
    
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

// Setup function
fn setup() -> (ContractAddress, ContractAddress) {
    let wbtc = deploy_mock_wbtc();
    let adapter = deploy_troves_adapter(OWNER(), VAULT(), wbtc);
    
    (adapter, wbtc)
}

// ===== CONSTRUCTOR TESTS =====

#[test]
fn test_constructor_initializes_correctly() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    let total_assets = adapter_dispatcher.get_total_assets();
    assert(total_assets == 0, 'Total assets should be 0');
    
    let active_strategies = adapter_dispatcher.get_active_strategies();
    assert(active_strategies.len() == 0, 'Should have no strategies');
}

// ===== STRATEGY MANAGEMENT TESTS =====

#[test]
fn test_add_strategy() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    let weight = 5000_u32; // 50%
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), weight);
    stop_cheat_caller_address(adapter);
    
    let active_strategies = adapter_dispatcher.get_active_strategies();
    assert(active_strategies.len() == 1, 'Should have 1 strategy');
    assert(*active_strategies.at(0) == 0, 'Wrong strategy ID');
}

#[test]
fn test_add_multiple_strategies() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), 5000);
    adapter_dispatcher.add_strategy(STRATEGY_2(), 5000);
    stop_cheat_caller_address(adapter);
    
    let active_strategies = adapter_dispatcher.get_active_strategies();
    assert(active_strategies.len() == 2, 'Should have 2 strategies');
}

#[test]
#[feature("safe_dispatcher")]
fn test_add_strategy_non_owner_fails() {
    let (adapter, _) = setup();
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, USER1());
    let result = safe_dispatcher.add_strategy(STRATEGY_1(), 5000);
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

#[test]
#[feature("safe_dispatcher")]
fn test_add_strategy_zero_address_fails() {
    let (adapter, _) = setup();
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    let zero_address: ContractAddress = Zero::zero();
    
    start_cheat_caller_address(adapter, OWNER());
    let result = safe_dispatcher.add_strategy(zero_address, 5000);
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

#[test]
fn test_remove_strategy() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), 5000);
    adapter_dispatcher.remove_strategy(0);
    stop_cheat_caller_address(adapter);
    
    let active_strategies = adapter_dispatcher.get_active_strategies();
    assert(active_strategies.len() == 0, 'Strategy not removed');
}

#[test]
#[feature("safe_dispatcher")]
fn test_remove_nonexistent_strategy_fails() {
    let (adapter, _) = setup();
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    let result = safe_dispatcher.remove_strategy(0);
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

#[test]
#[feature("safe_dispatcher")]
fn test_remove_strategy_non_owner_fails() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), 5000);
    stop_cheat_caller_address(adapter);
    
    start_cheat_caller_address(adapter, USER1());
    let result = safe_dispatcher.remove_strategy(0);
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

// ===== DEPOSIT TESTS (Placeholder - needs Troves implementation) =====

#[test]
fn test_deposit_to_strategy() {
    let (adapter, wbtc) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    let wbtc_erc20 = IERC20Dispatcher { contract_address: wbtc };
    
    // Add strategy
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), 5000);
    stop_cheat_caller_address(adapter);
    
    // Transfer WBTC to vault and approve
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.transfer(VAULT(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(wbtc, VAULT());
    wbtc_erc20.approve(adapter, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    // Deposit from vault (placeholder until Troves is implemented)
    start_cheat_caller_address(adapter, VAULT());
    let result = adapter_dispatcher.deposit(0, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    // NOTE: This validates the interface, actual implementation pending
    assert(result == DEPOSIT_AMOUNT(), 'Deposit result incorrect');
}

#[test]
#[feature("safe_dispatcher")]
fn test_deposit_unauthorized_fails() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), 5000);
    stop_cheat_caller_address(adapter);
    
    start_cheat_caller_address(adapter, USER1());
    let result = safe_dispatcher.deposit(0, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

#[test]
#[feature("safe_dispatcher")]
fn test_deposit_zero_amount_fails() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), 5000);
    stop_cheat_caller_address(adapter);
    
    start_cheat_caller_address(adapter, VAULT());
    let result = safe_dispatcher.deposit(0, 0);
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

#[test]
#[feature("safe_dispatcher")]
fn test_deposit_inactive_strategy_fails() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), 5000);
    adapter_dispatcher.remove_strategy(0);
    stop_cheat_caller_address(adapter);
    
    start_cheat_caller_address(adapter, VAULT());
    let result = safe_dispatcher.deposit(0, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

// ===== WITHDRAW TESTS (Placeholder - needs Troves implementation) =====

#[test]
fn test_withdraw_from_strategy() {
    let (adapter, wbtc) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    let wbtc_erc20 = IERC20Dispatcher { contract_address: wbtc };
    
    // Setup: Add strategy and simulate deposit
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), 5000);
    stop_cheat_caller_address(adapter);
    
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.transfer(VAULT(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(wbtc, VAULT());
    wbtc_erc20.approve(adapter, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(adapter, VAULT());
    adapter_dispatcher.deposit(0, DEPOSIT_AMOUNT());
    
    // Withdraw (placeholder implementation)
    let result = adapter_dispatcher.withdraw(0, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    assert(result == DEPOSIT_AMOUNT(), 'Withdraw result incorrect');
}

#[test]
#[feature("safe_dispatcher")]
fn test_withdraw_unauthorized_fails() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), 5000);
    stop_cheat_caller_address(adapter);
    
    start_cheat_caller_address(adapter, USER1());
    let result = safe_dispatcher.withdraw(0, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

// ===== HARVEST REWARDS TESTS (Placeholder) =====

#[test]
fn test_harvest_rewards() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), 5000);
    
    // Harvest rewards (placeholder - returns 0 until implemented)
    let rewards = adapter_dispatcher.harvest_rewards(0);
    stop_cheat_caller_address(adapter);
    
    assert(rewards == 0, 'Unexpected rewards');
}

#[test]
#[feature("safe_dispatcher")]
fn test_harvest_rewards_non_owner_fails() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), 5000);
    stop_cheat_caller_address(adapter);
    
    start_cheat_caller_address(adapter, USER1());
    let result = safe_dispatcher.harvest_rewards(0);
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

#[test]
#[feature("safe_dispatcher")]
fn test_harvest_rewards_inactive_strategy_fails() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), 5000);
    adapter_dispatcher.remove_strategy(0);
    
    let result = safe_dispatcher.harvest_rewards(0);
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

// ===== VIEW FUNCTION TESTS =====

#[test]
fn test_get_total_assets_initial() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    let total = adapter_dispatcher.get_total_assets();
    assert(total == 0, 'Should be zero initially');
}

#[test]
fn test_get_strategy_balance() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), 5000);
    stop_cheat_caller_address(adapter);
    
    let balance = adapter_dispatcher.get_strategy_balance(0);
    assert(balance == 0, 'Should be zero initially');
}

#[test]
fn test_get_strategy_balance_inactive() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), 5000);
    adapter_dispatcher.remove_strategy(0);
    stop_cheat_caller_address(adapter);
    
    let balance = adapter_dispatcher.get_strategy_balance(0);
    assert(balance == 0, 'Inactive strategy should be 0');
}

#[test]
fn test_get_active_strategies_empty() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    let strategies = adapter_dispatcher.get_active_strategies();
    assert(strategies.len() == 0, 'Should have no strategies');
}

#[test]
fn test_get_active_strategies_after_removal() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), 5000);
    adapter_dispatcher.add_strategy(STRATEGY_2(), 3000);
    adapter_dispatcher.remove_strategy(0);
    stop_cheat_caller_address(adapter);
    
    let strategies = adapter_dispatcher.get_active_strategies();
    assert(strategies.len() == 1, 'Should have 1 strategy');
    assert(*strategies.at(0) == 1, 'Wrong strategy ID');
}

// ===== TROVES ADDRESS UPDATE TESTS =====

#[test]
fn test_update_troves_addresses() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    let new_manager: ContractAddress = 'NEW_MANAGER'.try_into().unwrap();
    let new_staking: ContractAddress = 'NEW_STAKING'.try_into().unwrap();
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.update_troves_addresses(new_manager, new_staking);
    stop_cheat_caller_address(adapter);
}

#[test]
#[feature("safe_dispatcher")]
fn test_update_troves_addresses_non_owner_fails() {
    let (adapter, _) = setup();
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    let new_manager: ContractAddress = 'NEW_MANAGER'.try_into().unwrap();
    let new_staking: ContractAddress = 'NEW_STAKING'.try_into().unwrap();
    
    start_cheat_caller_address(adapter, USER1());
    let result = safe_dispatcher.update_troves_addresses(new_manager, new_staking);
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

// ===== INTEGRATION-STYLE TESTS =====

#[test]
fn test_multiple_strategies_with_different_weights() {
    let (adapter, _) = setup();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(STRATEGY_1(), 7000); // 70%
    adapter_dispatcher.add_strategy(STRATEGY_2(), 3000); // 30%
    stop_cheat_caller_address(adapter);
    
    let strategies = adapter_dispatcher.get_active_strategies();
    assert(strategies.len() == 2, 'Should have 2 strategies');
}