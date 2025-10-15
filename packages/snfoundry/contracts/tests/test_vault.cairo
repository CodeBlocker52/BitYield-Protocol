use starknet::ContractAddress;


use snforge_std_deprecated::{
    declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address,
    stop_cheat_caller_address
};

use bityield_contracts::interfaces::IBitYieldVault::{
    IBitYieldVaultDispatcher, IBitYieldVaultDispatcherTrait, IBitYieldVaultSafeDispatcher,
    IBitYieldVaultSafeDispatcherTrait
};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};


fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}

fn USER1() -> ContractAddress {
    'USER1'.try_into().unwrap()
}

fn USER2() -> ContractAddress {
    'USER2'.try_into().unwrap()
}

fn FEE_RECIPIENT() -> ContractAddress {
    'FEE_RECIPIENT'.try_into().unwrap()
}

fn INITIAL_SUPPLY() -> u256 {
    1000000_u256 * 100000000_u256
}

fn DEPOSIT_AMOUNT() -> u256 {
    100_u256 * 100000000_u256
}

fn deploy_mock_wbtc() -> ContractAddress {
    let contract = declare("MockWBTC").unwrap().contract_class();
    let mut calldata = ArrayTrait::new();
    OWNER().serialize(ref calldata);
    INITIAL_SUPPLY().serialize(ref calldata);
    
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

fn deploy_vault(
    owner: ContractAddress,
    asset: ContractAddress,
    strategy_manager: ContractAddress,
    vesu_adapter: ContractAddress,
    troves_adapter: ContractAddress,
    fee_recipient: ContractAddress
) -> ContractAddress {
    let contract = declare("BitYieldVault").unwrap().contract_class();
    
    let mut calldata = ArrayTrait::new();
    owner.serialize(ref calldata);
    asset.serialize(ref calldata);
    strategy_manager.serialize(ref calldata);
    vesu_adapter.serialize(ref calldata);
    troves_adapter.serialize(ref calldata);
    fee_recipient.serialize(ref calldata);
    
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

fn setup() -> (ContractAddress, ContractAddress) {
    let wbtc = deploy_mock_wbtc();
    let strategy_manager: ContractAddress = 'STRATEGY_MGR'.try_into().unwrap();
    let vesu_adapter: ContractAddress = 'VESU_ADAPTER'.try_into().unwrap();
    let troves_adapter: ContractAddress = 'TROVES_ADAPTER'.try_into().unwrap();
    
    let vault = deploy_vault(
        OWNER(),
        wbtc,
        strategy_manager,
        vesu_adapter,
        troves_adapter,
        FEE_RECIPIENT()
    );
    
    (vault, wbtc)
}

// ===== CONSTRUCTOR TESTS =====

#[test]
fn test_constructor_initializes_correctly() {
    let (vault, wbtc) = setup();
    let vault_dispatcher = IBitYieldVaultDispatcher { contract_address: vault };
    
    let config = vault_dispatcher.get_config();
    
    assert(config.asset == wbtc, 'Wrong asset address');
    assert(config.fee_recipient == FEE_RECIPIENT(), 'Wrong fee recipient');
    assert(config.performance_fee_bps == 100, 'Wrong performance fee');
    assert(config.management_fee_bps == 50, 'Wrong management fee');
    assert(config.max_vesu_weight_bps == 7000, 'Wrong max vesu weight');
    assert(config.max_troves_weight_bps == 3000, 'Wrong max troves weight');
}

// ===== DEPOSIT TESTS =====

#[test]
fn test_first_deposit() {
    let (vault, wbtc) = setup();
    let vault_dispatcher = IBitYieldVaultDispatcher { contract_address: vault };
    let wbtc_erc20 = IERC20Dispatcher { contract_address: wbtc };
    let vault_erc20 = IERC20Dispatcher { contract_address: vault };
    
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.transfer(USER1(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(wbtc, USER1());
    wbtc_erc20.approve(vault, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(vault, USER1());
    let shares = vault_dispatcher.deposit(DEPOSIT_AMOUNT());
    stop_cheat_caller_address(vault);
    
    assert(shares == DEPOSIT_AMOUNT(), 'Wrong shares minted');
    assert(vault_erc20.balance_of(USER1()) == shares, 'Wrong user balance');
    assert(vault_dispatcher.total_assets() == DEPOSIT_AMOUNT(), 'Wrong total assets');
}

#[test]
fn test_multiple_deposits_same_user() {
    let (vault, wbtc) = setup();
    let vault_dispatcher = IBitYieldVaultDispatcher { contract_address: vault };
    let wbtc_erc20 = IERC20Dispatcher { contract_address: wbtc };
    let vault_erc20 = IERC20Dispatcher { contract_address: vault };
    
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.transfer(USER1(), DEPOSIT_AMOUNT() * 2);
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(wbtc, USER1());
    wbtc_erc20.approve(vault, DEPOSIT_AMOUNT() * 2);
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(vault, USER1());
    let shares1 = vault_dispatcher.deposit(DEPOSIT_AMOUNT());
    let shares2 = vault_dispatcher.deposit(DEPOSIT_AMOUNT());
    stop_cheat_caller_address(vault);
    
    assert(vault_erc20.balance_of(USER1()) == shares1 + shares2, 'Wrong total shares');
}

#[test]
fn test_multiple_users_deposit() {
    let (vault, wbtc) = setup();
    let vault_dispatcher = IBitYieldVaultDispatcher { contract_address: vault };
    let wbtc_erc20 = IERC20Dispatcher { contract_address: wbtc };
    let vault_erc20 = IERC20Dispatcher { contract_address: vault };
    
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.transfer(USER1(), DEPOSIT_AMOUNT());
    wbtc_erc20.transfer(USER2(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(wbtc, USER1());
    wbtc_erc20.approve(vault, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(vault, USER1());
    let shares1 = vault_dispatcher.deposit(DEPOSIT_AMOUNT());
    stop_cheat_caller_address(vault);
    
    start_cheat_caller_address(wbtc, USER2());
    wbtc_erc20.approve(vault, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(vault, USER2());
    let shares2 = vault_dispatcher.deposit(DEPOSIT_AMOUNT());
    stop_cheat_caller_address(vault);
    
    assert(vault_erc20.balance_of(USER1()) == shares1, 'Wrong USER1 balance');
    assert(vault_erc20.balance_of(USER2()) == shares2, 'Wrong USER2 balance');
}

#[test]
#[feature("safe_dispatcher")]
fn test_deposit_zero_amount_fails() {
    let (vault, _) = setup();
    let safe_dispatcher = IBitYieldVaultSafeDispatcher { contract_address: vault };
    
    start_cheat_caller_address(vault, USER1());
    let result = safe_dispatcher.deposit(0);
    stop_cheat_caller_address(vault);
    
    assert(result.is_err(), 'Should have failed');
}

// ===== WITHDRAW TESTS =====

#[test]
fn test_withdraw_full_amount() {
    let (vault, wbtc) = setup();
    let vault_dispatcher = IBitYieldVaultDispatcher { contract_address: vault };
    let wbtc_erc20 = IERC20Dispatcher { contract_address: wbtc };
    let vault_erc20 = IERC20Dispatcher { contract_address: vault };
    
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.transfer(USER1(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(wbtc, USER1());
    wbtc_erc20.approve(vault, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(vault, USER1());
    let shares = vault_dispatcher.deposit(DEPOSIT_AMOUNT());
    let assets = vault_dispatcher.withdraw(shares);
    stop_cheat_caller_address(vault);
    
    assert(assets == DEPOSIT_AMOUNT(), 'Wrong assets withdrawn');
    assert(vault_erc20.balance_of(USER1()) == 0, 'Shares not burned');
    assert(wbtc_erc20.balance_of(USER1()) == DEPOSIT_AMOUNT(), 'WBTC not returned');
}

#[test]
fn test_withdraw_partial_amount() {
    let (vault, wbtc) = setup();
    let vault_dispatcher = IBitYieldVaultDispatcher { contract_address: vault };
    let wbtc_erc20 = IERC20Dispatcher { contract_address: wbtc };
    let vault_erc20 = IERC20Dispatcher { contract_address: vault };
    
    start_cheat_caller_address(wbtc, OWNER());
    wbtc_erc20.transfer(USER1(), DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(wbtc, USER1());
    wbtc_erc20.approve(vault, DEPOSIT_AMOUNT());
    stop_cheat_caller_address(wbtc);
    
    start_cheat_caller_address(vault, USER1());
    let shares = vault_dispatcher.deposit(DEPOSIT_AMOUNT());
    let half_shares = shares / 2;
    let assets = vault_dispatcher.withdraw(half_shares);
    stop_cheat_caller_address(vault);
    
    assert(vault_erc20.balance_of(USER1()) == half_shares, 'Wrong remaining shares');
    assert(assets <= DEPOSIT_AMOUNT() / 2 + 1, 'Wrong assets withdrawn');
}

#[test]
#[feature("safe_dispatcher")]
fn test_withdraw_zero_shares_fails() {
    let (vault, _) = setup();
    let safe_dispatcher = IBitYieldVaultSafeDispatcher { contract_address: vault };
    
    start_cheat_caller_address(vault, USER1());
    let result = safe_dispatcher.withdraw(0);
    stop_cheat_caller_address(vault);
    
    assert(result.is_err(), 'Should have failed');
}

// ===== CONVERSION TESTS =====

#[test]
fn test_convert_to_shares() {
    let (vault, _) = setup();
    let vault_dispatcher = IBitYieldVaultDispatcher { contract_address: vault };
    
    let assets = 1000_u256;
    let shares = vault_dispatcher.convert_to_shares(assets);
    
    assert(shares == assets, 'Wrong conversion');
}

#[test]
fn test_convert_to_assets() {
    let (vault, _) = setup();
    let vault_dispatcher = IBitYieldVaultDispatcher { contract_address: vault };
    
    let shares = 1000_u256;
    let assets = vault_dispatcher.convert_to_assets(shares);
    
    assert(assets == 0, 'Wrong conversion');
}

// ===== ACCESS CONTROL TESTS =====

#[test]
fn test_pause_by_owner() {
    let (vault, _) = setup();
    let vault_dispatcher = IBitYieldVaultDispatcher { contract_address: vault };
    
    start_cheat_caller_address(vault, OWNER());
    vault_dispatcher.pause();
    stop_cheat_caller_address(vault);
}

#[test]
#[feature("safe_dispatcher")]
fn test_pause_by_non_owner_fails() {
    let (vault, _) = setup();
    let safe_dispatcher = IBitYieldVaultSafeDispatcher { contract_address: vault };
    
    start_cheat_caller_address(vault, USER1());
    let result = safe_dispatcher.pause();
    stop_cheat_caller_address(vault);
    
    assert(result.is_err(), 'Should have failed');
}

// ===== FEE CONFIGURATION TESTS =====

#[test]
fn test_update_fees_by_owner() {
    let (vault, _) = setup();
    let vault_dispatcher = IBitYieldVaultDispatcher { contract_address: vault };
    
    let new_performance_fee = 200_u32;
    let new_management_fee = 100_u32;
    
    start_cheat_caller_address(vault, OWNER());
    vault_dispatcher.update_fees(new_performance_fee, new_management_fee);
    stop_cheat_caller_address(vault);
    
    let config = vault_dispatcher.get_config();
    assert(config.performance_fee_bps == new_performance_fee, 'Performance fee not updated');
    assert(config.management_fee_bps == new_management_fee, 'Management fee not updated');
}

// ===== STRATEGY UPDATE TESTS =====

#[test]
fn test_update_vesu_strategy() {
    let (vault, _) = setup();
    let vault_dispatcher = IBitYieldVaultDispatcher { contract_address: vault };
    let new_adapter: ContractAddress = 'NEW_VESU'.try_into().unwrap();
    
    start_cheat_caller_address(vault, OWNER());
    vault_dispatcher.update_strategy('vesu', new_adapter);
    stop_cheat_caller_address(vault);
    
    let config = vault_dispatcher.get_config();
    assert(config.vesu_adapter == new_adapter, 'Vesu adapter not updated');
}