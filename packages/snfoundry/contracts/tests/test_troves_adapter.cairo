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
use bityield_contracts::mocks::MockTrovesStrategy::{
    IMockTrovesStrategyDispatcher, IMockTrovesStrategyDispatcherTrait
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

// Deploy MockTrovesStrategy
fn deploy_mock_troves_strategy(asset: ContractAddress) -> ContractAddress {
    let contract = declare("MockTrovesStrategy").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    asset.serialize(ref calldata);
    
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

// Setup with deployed strategy
fn setup_with_strategy() -> (ContractAddress, ContractAddress, ContractAddress) {
    let wbtc = deploy_mock_wbtc();
    let adapter = deploy_troves_adapter(OWNER(), VAULT(), wbtc);
    let strategy = deploy_mock_troves_strategy(wbtc);
    
    // Add strategy to adapter
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(strategy, 5000);
    stop_cheat_caller_address(adapter);
    
    (adapter, wbtc, strategy)
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
    let (adapter, wbtc) = setup();
    let strategy = deploy_mock_troves_strategy(wbtc);
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    let weight = 5000_u32; // 50%
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(strategy, weight);
    stop_cheat_caller_address(adapter);
    
    let active_strategies = adapter_dispatcher.get_active_strategies();
    assert(active_strategies.len() == 1, 'Should have 1 strategy');
    assert(*active_strategies.at(0) == 0, 'Wrong strategy ID');
}

#[test]
fn test_add_multiple_strategies() {
    let (adapter, wbtc) = setup();
    let strategy1 = deploy_mock_troves_strategy(wbtc);
    let strategy2 = deploy_mock_troves_strategy(wbtc);
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(strategy1, 5000);
    adapter_dispatcher.add_strategy(strategy2, 5000);
    stop_cheat_caller_address(adapter);
    
    let active_strategies = adapter_dispatcher.get_active_strategies();
    assert(active_strategies.len() == 2, 'Should have 2 strategies');
}

#[test]
#[feature("safe_dispatcher")]
fn test_add_strategy_non_owner_fails() {
    let (adapter, wbtc) = setup();
    let strategy = deploy_mock_troves_strategy(wbtc);
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, USER1());
    let result = safe_dispatcher.add_strategy(strategy, 5000);
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
    let (adapter, wbtc) = setup();
    let strategy = deploy_mock_troves_strategy(wbtc);
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(strategy, 5000);
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
    let (adapter, wbtc) = setup();
    let strategy = deploy_mock_troves_strategy(wbtc);
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(strategy, 5000);
    stop_cheat_caller_address(adapter);
    
    start_cheat_caller_address(adapter, USER1());
    let result = safe_dispatcher.remove_strategy(0);
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

// ===== DEPOSIT TESTS =====

#[test]
fn test_deposit_to_strategy() {
    let (adapter, wbtc, strategy) = setup_with_strategy();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    let wbtc_erc20 = IERC20Dispatcher { contract_address: wbtc };
    
    // Transfer WBTC to vault
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.transfer(VAULT(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    // Approve adapter to spend vault's WBTC
    start_cheat_caller_address(wbtc, VAULT());
    wbtc_erc20.approve(adapter, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    // Deposit from vault
    start_cheat_caller_address(adapter, VAULT());
    let shares = adapter_dispatcher.deposit(0, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    assert(shares == DEPOSIT_AMOUNT(), 'Wrong shares returned');
    
    // Verify balance
    let balance = adapter_dispatcher.get_strategy_balance(0);
    assert(balance == DEPOSIT_AMOUNT(), 'Wrong strategy balance');
}

#[test]
#[feature("safe_dispatcher")]
fn test_deposit_unauthorized_fails() {
    let (adapter, _, _) = setup_with_strategy();
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, USER1());
    let result = safe_dispatcher.deposit(0, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

#[test]
#[feature("safe_dispatcher")]
fn test_deposit_zero_amount_fails() {
    let (adapter, _, _) = setup_with_strategy();
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, VAULT());
    let result = safe_dispatcher.deposit(0, 0);
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

#[test]
#[feature("safe_dispatcher")]
fn test_deposit_inactive_strategy_fails() {
    let (adapter, wbtc, _) = setup_with_strategy();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    // Remove strategy
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.remove_strategy(0);
    stop_cheat_caller_address(adapter);
    
    // Try to deposit
    start_cheat_caller_address(adapter, VAULT());
    let result = safe_dispatcher.deposit(0, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

// ===== WITHDRAW TESTS =====

#[test]
fn test_withdraw_from_strategy() {
    let (adapter, wbtc, strategy) = setup_with_strategy();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    let wbtc_erc20 = IERC20Dispatcher { contract_address: wbtc };
    
    // Setup: Transfer and approve
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.transfer(VAULT(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(wbtc, VAULT());
    wbtc_erc20.approve(adapter, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    // Deposit
    start_cheat_caller_address(adapter, VAULT());
    adapter_dispatcher.deposit(0, DEPOSIT_AMOUNT());
    
    // Check vault balance before withdraw
    let vault_balance_before = wbtc_erc20.balance_of(VAULT());
    
    // Withdraw
    let withdrawn_amount = adapter_dispatcher.withdraw(0, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    // Verify withdrawn amount
    assert(withdrawn_amount == DEPOSIT_AMOUNT(), 'Wrong withdraw amount');
    
    // Verify vault received tokens
    let vault_balance_after = wbtc_erc20.balance_of(VAULT());
    assert(vault_balance_after == vault_balance_before + DEPOSIT_AMOUNT(), 'Vault balance wrong');
}

#[test]
#[feature("safe_dispatcher")]
fn test_withdraw_unauthorized_fails() {
    let (adapter, _, _) = setup_with_strategy();
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, USER1());
    let result = safe_dispatcher.withdraw(0, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

// ===== HARVEST REWARDS TESTS =====

#[test]
fn test_harvest_rewards() {
    let (adapter, wbtc, strategy) = setup_with_strategy();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    let wbtc_erc20 = IERC20Dispatcher { contract_address: wbtc };
    let strategy_dispatcher = IMockTrovesStrategyDispatcher { contract_address: strategy };
    
    // Setup: Deposit some funds
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.transfer(VAULT(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(wbtc, VAULT());
    wbtc_erc20.approve(adapter, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(adapter, VAULT());
    adapter_dispatcher.deposit(0, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    // Simulate yield by setting yield in mock strategy
    let yield_amount = 10_u256 * 100000000_u256; // 10 WBTC yield
    
    // Transfer yield to strategy contract first
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.transfer(strategy, yield_amount);
    stop_cheat_caller_address(wbtc);
    
    // Set yield in strategy
    strategy_dispatcher.set_yield(yield_amount);
    
    // Harvest rewards
    start_cheat_caller_address(adapter, OWNER());
    let rewards = adapter_dispatcher.harvest_rewards(0);
    stop_cheat_caller_address(adapter);
    
    assert(rewards == yield_amount, 'Wrong rewards amount');
}

#[test]
#[feature("safe_dispatcher")]
fn test_harvest_rewards_non_owner_fails() {
    let (adapter, _, _) = setup_with_strategy();
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, USER1());
    let result = safe_dispatcher.harvest_rewards(0);
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

#[test]
#[feature("safe_dispatcher")]
fn test_harvest_rewards_inactive_strategy_fails() {
    let (adapter, _, _) = setup_with_strategy();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    let safe_dispatcher = ITrovesAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
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
    let (adapter, wbtc, strategy) = setup_with_strategy();
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    let wbtc_erc20 = IERC20Dispatcher { contract_address: wbtc };
    
    // Deposit some funds
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.transfer(VAULT(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(wbtc, VAULT());
    wbtc_erc20.approve(adapter, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(adapter, VAULT());
    adapter_dispatcher.deposit(0, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    let balance = adapter_dispatcher.get_strategy_balance(0);
    assert(balance == DEPOSIT_AMOUNT(), 'Wrong balance');
}

#[test]
fn test_get_strategy_balance_inactive() {
    let (adapter, wbtc) = setup();
    let strategy = deploy_mock_troves_strategy(wbtc);
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(strategy, 5000);
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
    let (adapter, wbtc) = setup();
    let strategy1 = deploy_mock_troves_strategy(wbtc);
    let strategy2 = deploy_mock_troves_strategy(wbtc);
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(strategy1, 5000);
    adapter_dispatcher.add_strategy(strategy2, 3000);
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
    let (adapter, wbtc) = setup();
    let strategy1 = deploy_mock_troves_strategy(wbtc);
    let strategy2 = deploy_mock_troves_strategy(wbtc);
    let adapter_dispatcher = ITrovesAdapterDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_strategy(strategy1, 7000); // 70%
    adapter_dispatcher.add_strategy(strategy2, 3000); // 30%
    stop_cheat_caller_address(adapter);
    
    let strategies = adapter_dispatcher.get_active_strategies();
    assert(strategies.len() == 2, 'Should have 2 strategies');
}