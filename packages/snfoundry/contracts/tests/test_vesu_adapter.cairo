use starknet::ContractAddress;
use core::num::traits::Zero;

use snforge_std_deprecated::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address
};

use bityield_contracts::interfaces::IVesuAdapter::{
    IVesuAdapterDispatcher, IVesuAdapterDispatcherTrait, IVesuAdapterSafeDispatcher,
    IVesuAdapterSafeDispatcherTrait
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

fn POOL_ID_1() -> felt252 {
    'pool_1'
}

fn POOL_ID_2() -> felt252 {
    'pool_2'
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

// Deploy mock VToken
fn deploy_mock_vtoken(asset: ContractAddress) -> ContractAddress {
    let contract = declare("MockVToken").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    asset.serialize(ref calldata);
    
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

// Deploy VesuAdapter
fn deploy_vesu_adapter(
    owner: ContractAddress, vault: ContractAddress, asset: ContractAddress
) -> ContractAddress {
    let contract = declare("VesuAdapter").unwrap().contract_class();
    
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref calldata);
    vault.serialize(ref calldata);
    asset.serialize(ref calldata);
    
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

// Setup function
fn setup() -> (ContractAddress, ContractAddress, ContractAddress) {
    let wbtc = deploy_mock_wbtc();
    let vtoken = deploy_mock_vtoken(wbtc);
    let adapter = deploy_vesu_adapter(OWNER(), VAULT(), wbtc);
    
    (adapter, wbtc, vtoken)
}

// ===== CONSTRUCTOR TESTS =====

#[test]
fn test_constructor_initializes_correctly() {
    let (adapter, _, _) = setup();
    let adapter_dispatcher = IVesuAdapterDispatcher { contract_address: adapter };
    
    let total_assets = adapter_dispatcher.get_total_assets();
    assert(total_assets == 0, 'Total assets should be 0');
    
    let active_pools = adapter_dispatcher.get_active_pools();
    assert(active_pools.len() == 0, 'Should have no pools');
}

// ===== POOL MANAGEMENT TESTS =====

#[test]
fn test_add_pool() {
    let (adapter, _, vtoken) = setup();
    let adapter_dispatcher = IVesuAdapterDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_pool(POOL_ID_1(), vtoken);
    stop_cheat_caller_address(adapter);
    
    let v_token_address = adapter_dispatcher.get_v_token(POOL_ID_1());
    assert(v_token_address == vtoken, 'VToken not added');
    
    let active_pools = adapter_dispatcher.get_active_pools();
    assert(active_pools.len() == 1, 'Wrong pool count');
    assert(*active_pools.at(0) == POOL_ID_1(), 'Wrong pool ID');
}

#[test]
fn test_add_multiple_pools() {
    let (adapter, wbtc, vtoken1) = setup();
    let adapter_dispatcher = IVesuAdapterDispatcher { contract_address: adapter };
    
    let vtoken2 = deploy_mock_vtoken(wbtc);
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_pool(POOL_ID_1(), vtoken1);
    adapter_dispatcher.add_pool(POOL_ID_2(), vtoken2);
    stop_cheat_caller_address(adapter);
    
    let active_pools = adapter_dispatcher.get_active_pools();
    assert(active_pools.len() == 2, 'Wrong pool count');
}

#[test]
#[feature("safe_dispatcher")]
fn test_add_pool_non_owner_fails() {
    let (adapter, _, vtoken) = setup();
    let safe_dispatcher = IVesuAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, USER1());
    let result = safe_dispatcher.add_pool(POOL_ID_1(), vtoken);
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

#[test]
#[feature("safe_dispatcher")]
fn test_add_pool_zero_address_fails() {
    let (adapter, _, _) = setup();
    let safe_dispatcher = IVesuAdapterSafeDispatcher { contract_address: adapter };
    let zero_address: ContractAddress = Zero::zero();
    
    start_cheat_caller_address(adapter, OWNER());
    let result = safe_dispatcher.add_pool(POOL_ID_1(), zero_address);
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

#[test]
#[feature("safe_dispatcher")]
fn test_add_duplicate_pool_fails() {
    let (adapter, _, vtoken) = setup();
    let adapter_dispatcher = IVesuAdapterDispatcher { contract_address: adapter };
    let safe_dispatcher = IVesuAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_pool(POOL_ID_1(), vtoken);
    
    let result = safe_dispatcher.add_pool(POOL_ID_1(), vtoken);
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

#[test]
fn test_remove_pool() {
    let (adapter, _, vtoken) = setup();
    let adapter_dispatcher = IVesuAdapterDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_pool(POOL_ID_1(), vtoken);
    adapter_dispatcher.remove_pool(POOL_ID_1());
    stop_cheat_caller_address(adapter);
    
    let v_token_address = adapter_dispatcher.get_v_token(POOL_ID_1());
    assert(v_token_address.is_zero(), 'Pool not removed');
}

#[test]
#[feature("safe_dispatcher")]
fn test_remove_nonexistent_pool_fails() {
    let (adapter, _, _) = setup();
    let safe_dispatcher = IVesuAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    let result = safe_dispatcher.remove_pool(POOL_ID_1());
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

// ===== DEPOSIT TESTS =====

#[test]
fn test_deposit_from_vault() {
    let (adapter, wbtc, vtoken) = setup();
    let adapter_dispatcher = IVesuAdapterDispatcher { contract_address: adapter };
    let wbtc_erc20 = IERC20Dispatcher { contract_address: wbtc };
    
    // Add pool
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_pool(POOL_ID_1(), vtoken);
    stop_cheat_caller_address(adapter);
    
    // Transfer WBTC to vault and approve adapter
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.transfer(VAULT(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(wbtc, VAULT());
    wbtc_erc20.approve(adapter, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    // Deposit from vault
    start_cheat_caller_address(adapter, VAULT());
    let shares = adapter_dispatcher.deposit(POOL_ID_1(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    assert(shares > 0, 'No shares returned');
    let balance = adapter_dispatcher.get_pool_balance(POOL_ID_1());
    assert(balance == DEPOSIT_AMOUNT(), 'Wrong pool balance');
}

#[test]
fn test_deposit_from_owner() {
    let (adapter, wbtc, vtoken) = setup();
    let adapter_dispatcher = IVesuAdapterDispatcher { contract_address: adapter };
    let wbtc_erc20 = IERC20Dispatcher { contract_address: wbtc };
    
    // Add pool
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_pool(POOL_ID_1(), vtoken);
    stop_cheat_caller_address(adapter);
    
    // Approve adapter
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.approve(adapter, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    // Deposit from owner
    start_cheat_caller_address(adapter, OWNER());
    let shares = adapter_dispatcher.deposit(POOL_ID_1(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    assert(shares > 0, 'No shares returned');
}

#[test]
#[feature("safe_dispatcher")]
fn test_deposit_unauthorized_fails() {
    let (adapter, _, vtoken) = setup();
    let safe_dispatcher = IVesuAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    let _ = safe_dispatcher.add_pool(POOL_ID_1(), vtoken);
    stop_cheat_caller_address(adapter);
    
    start_cheat_caller_address(adapter, USER1());
    let result = safe_dispatcher.deposit(POOL_ID_1(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

#[test]
#[feature("safe_dispatcher")]
fn test_deposit_zero_amount_fails() {
    let (adapter, _, vtoken) = setup();
    let adapter_dispatcher = IVesuAdapterDispatcher { contract_address: adapter };
    let safe_dispatcher = IVesuAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_pool(POOL_ID_1(), vtoken);
    
    let result = safe_dispatcher.deposit(POOL_ID_1(), 0);
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

#[test]
#[feature("safe_dispatcher")]
fn test_deposit_nonexistent_pool_fails() {
    let (adapter, _, _) = setup();
    let safe_dispatcher = IVesuAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, VAULT());
    let result = safe_dispatcher.deposit(POOL_ID_1(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

// ===== WITHDRAW TESTS =====

#[test]
fn test_withdraw() {
    let (adapter, wbtc, vtoken) = setup();
    let adapter_dispatcher = IVesuAdapterDispatcher { contract_address: adapter };
    let wbtc_erc20 = IERC20Dispatcher { contract_address: wbtc };
    
    // Setup: Add pool and deposit
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_pool(POOL_ID_1(), vtoken);
    stop_cheat_caller_address(adapter);
    
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.transfer(VAULT(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(wbtc, VAULT());
    wbtc_erc20.approve(adapter, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(adapter, VAULT());
    adapter_dispatcher.deposit(POOL_ID_1(), DEPOSIT_AMOUNT());
    
    // Withdraw
    let withdraw_amount = DEPOSIT_AMOUNT() / 2;
    let shares = adapter_dispatcher.withdraw(POOL_ID_1(), withdraw_amount);
    stop_cheat_caller_address(adapter);
    
    assert(shares > 0, 'No shares returned');
    let vault_balance = wbtc_erc20.balance_of(VAULT());
    assert(vault_balance == withdraw_amount, 'Wrong withdrawal amount');
}

#[test]
fn test_withdraw_all() {
    let (adapter, wbtc, vtoken) = setup();
    let adapter_dispatcher = IVesuAdapterDispatcher { contract_address: adapter };
    let wbtc_erc20 = IERC20Dispatcher { contract_address: wbtc };
    
    // Setup: Add pool and deposit
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_pool(POOL_ID_1(), vtoken);
    stop_cheat_caller_address(adapter);
    
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.transfer(VAULT(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(wbtc, VAULT());
    wbtc_erc20.approve(adapter, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(adapter, VAULT());
    adapter_dispatcher.deposit(POOL_ID_1(), DEPOSIT_AMOUNT());
    
    // Withdraw all
    let withdrawn = adapter_dispatcher.withdraw_all(POOL_ID_1());
    stop_cheat_caller_address(adapter);
    
    assert(withdrawn == DEPOSIT_AMOUNT(), 'Wrong withdrawal amount');
    let balance = adapter_dispatcher.get_pool_balance(POOL_ID_1());
    assert(balance == 0, 'Balance not zero');
}

#[test]
#[feature("safe_dispatcher")]
fn test_withdraw_unauthorized_fails() {
    let (adapter, _, vtoken) = setup();
    let adapter_dispatcher = IVesuAdapterDispatcher { contract_address: adapter };
    let safe_dispatcher = IVesuAdapterSafeDispatcher { contract_address: adapter };
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_pool(POOL_ID_1(), vtoken);
    stop_cheat_caller_address(adapter);
    
    start_cheat_caller_address(adapter, USER1());
    let result = safe_dispatcher.withdraw(POOL_ID_1(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    assert(result.is_err(), 'Should have failed');
}

// ===== VIEW FUNCTION TESTS =====

#[test]
fn test_get_total_assets_multiple_pools() {
    let (adapter, wbtc, vtoken1) = setup();
    let adapter_dispatcher = IVesuAdapterDispatcher { contract_address: adapter };
    let wbtc_erc20 = IERC20Dispatcher { contract_address: wbtc };
    
    let vtoken2 = deploy_mock_vtoken(wbtc);
    
    // Add pools
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_pool(POOL_ID_1(), vtoken1);
    adapter_dispatcher.add_pool(POOL_ID_2(), vtoken2);
    stop_cheat_caller_address(adapter);
    
    // Deposit to both pools
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.transfer(VAULT(), DEPOSIT_AMOUNT() * 2);
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(wbtc, VAULT());
    wbtc_erc20.approve(adapter, DEPOSIT_AMOUNT() * 2);
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(adapter, VAULT());
    adapter_dispatcher.deposit(POOL_ID_1(), DEPOSIT_AMOUNT());
    adapter_dispatcher.deposit(POOL_ID_2(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(adapter);
    
    let total = adapter_dispatcher.get_total_assets();
    assert(total == DEPOSIT_AMOUNT() * 2, 'Wrong total assets');
}

#[test]
fn test_get_pool_balance_nonexistent() {
    let (adapter, _, _) = setup();
    let adapter_dispatcher = IVesuAdapterDispatcher { contract_address: adapter };
    
    let balance = adapter_dispatcher.get_pool_balance(POOL_ID_1());
    assert(balance == 0, 'Should be zero');
}

#[test]
fn test_get_active_pools_after_removal() {
    let (adapter, wbtc, vtoken1) = setup();
    let adapter_dispatcher = IVesuAdapterDispatcher { contract_address: adapter };
    let vtoken2 = deploy_mock_vtoken(wbtc);
    
    start_cheat_caller_address(adapter, OWNER());
    adapter_dispatcher.add_pool(POOL_ID_1(), vtoken1);
    adapter_dispatcher.add_pool(POOL_ID_2(), vtoken2);
    adapter_dispatcher.remove_pool(POOL_ID_1());
    stop_cheat_caller_address(adapter);
    
    let active_pools = adapter_dispatcher.get_active_pools();
    assert(active_pools.len() == 1, 'Wrong pool count');
    assert(*active_pools.at(0) == POOL_ID_2(), 'Wrong remaining pool');
}