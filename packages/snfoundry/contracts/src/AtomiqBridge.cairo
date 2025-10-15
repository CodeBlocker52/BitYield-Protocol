use starknet::ContractAddress;

// Import from the interfaces module
use bityield_contracts::interfaces::IAtomiqBridge::{BridgeRequest, BridgeStatus};

#[starknet::interface]
pub trait IAtomiqBridge<TContractState> {
    fn initiate_bridge(ref self: TContractState, btc_tx_hash: felt252, btc_amount: u256, auto_deposit: bool);
    fn complete_bridge(ref self: TContractState, btc_tx_hash: felt252, wbtc_amount: u256);
    fn initiate_withdrawal(ref self: TContractState, wbtc_amount: u256, btc_address: ByteArray);
    fn set_auto_deposit(ref self: TContractState, enabled: bool);
    fn get_bridge_request(self: @TContractState, tx_hash: felt252) -> BridgeRequest;
    fn get_pending_deposit(self: @TContractState, user: ContractAddress) -> u256;
    fn is_auto_deposit_enabled(self: @TContractState, user: ContractAddress) -> bool;
    fn update_atomiq_addresses(ref self: TContractState, gateway: ContractAddress, router: ContractAddress);
    fn update_bridge_config(ref self: TContractState, min_amount: u256, max_amount: u256, fee_bps: u32);
    fn get_bridge_config(self: @TContractState) -> (u256, u256, u32);
    fn set_relayer(ref self: TContractState, relayer: ContractAddress);
    fn get_relayer(self: @TContractState) -> ContractAddress;
}

#[starknet::contract]
mod AtomiqBridge {
    use super::{BridgeRequest, BridgeStatus};
    use starknet::{ContractAddress, get_contract_address, get_caller_address};
   
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry
    };

    // Define Atomiq Gateway interface locally to avoid import issues
    #[starknet::interface]
    trait IAtomiqGateway<TContractState> {
        fn complete_btc_bridge(
            ref self: TContractState,
            btc_tx_hash: felt252,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool;
    }

    // Define BitYield Vault interface locally
    #[starknet::interface]
    trait IVault<TContractState> {
        fn deposit(ref self: TContractState, assets: u256) -> u256;
    }

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        atomiq_gateway: ContractAddress,
        atomiq_router: ContractAddress,
        atomiq_relayer: ContractAddress,
        wbtc_token: ContractAddress,
        bityield_vault: ContractAddress,
        bridge_requests: Map<felt252, BridgeRequest>,
        pending_deposits: Map<ContractAddress, u256>,
        bridge_fee_bps: u32,
        min_bridge_amount: u256,
        max_bridge_amount: u256,
        auto_deposit_enabled: Map<ContractAddress, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        BridgeInitiated: BridgeInitiated,
        BridgeCompleted: BridgeCompleted,
        AutoDepositExecuted: AutoDepositExecuted,
        WithdrawalInitiated: WithdrawalInitiated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BridgeInitiated {
        #[key]
        pub user: ContractAddress,
        #[key]
        pub tx_hash: felt252,
        pub btc_amount: u256,
        pub expected_wbtc: u256,
        pub auto_deposit: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BridgeCompleted {
        #[key]
        pub user: ContractAddress,
        #[key]
        pub tx_hash: felt252,
        pub wbtc_received: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct AutoDepositExecuted {
        #[key]
        pub user: ContractAddress,
        pub wbtc_amount: u256,
        pub vault_shares: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WithdrawalInitiated {
        #[key]
        pub user: ContractAddress,
        pub wbtc_amount: u256,
        pub btc_address: ByteArray,
    }

    // Error constants
    pub const ZERO_ADDRESS: felt252 = 'Zero address not allowed';
    pub const ZERO_AMOUNT: felt252 = 'Amount must be greater than 0';
    pub const BELOW_MINIMUM: felt252 = 'Below minimum bridge amount';
    pub const ABOVE_MAXIMUM: felt252 = 'Above maximum bridge amount';
    pub const REQUEST_NOT_FOUND: felt252 = 'Bridge request not found';
    pub const INVALID_STATUS: felt252 = 'Invalid request status';
    pub const UNAUTHORIZED: felt252 = 'Unauthorized caller';
    pub const TRANSFER_FAILED: felt252 = 'Token transfer failed';

    #[constructor]
    fn constructor(
        ref self: ContractState,
        owner: ContractAddress,
        atomiq_gateway: ContractAddress,
        atomiq_router: ContractAddress,
        atomiq_relayer: ContractAddress,
        wbtc_token: ContractAddress,
        bityield_vault: ContractAddress,
    ) {
        self.ownable.initializer(owner);
        self.atomiq_gateway.write(atomiq_gateway);
        self.atomiq_router.write(atomiq_router);
        self.atomiq_relayer.write(atomiq_relayer);
        self.wbtc_token.write(wbtc_token);
        self.bityield_vault.write(bityield_vault);
        
        // Default bridge limits (0.001 BTC to 10 BTC)
        self.min_bridge_amount.write(100000);  // 0.001 BTC in satoshis
        self.max_bridge_amount.write(1000000000);  // 10 BTC in satoshis
        
        // Default bridge fee: 0.1%
        self.bridge_fee_bps.write(10);
    }

    #[abi(embed_v0)]
    impl AtomiqBridgeImpl of super::IAtomiqBridge<ContractState> {
        fn initiate_bridge(
            ref self: ContractState,
            btc_tx_hash: felt252,
            btc_amount: u256,
            auto_deposit: bool,
        ) {
            let caller = get_caller_address();
            self._validate_bridge_amount(btc_amount);
            
            // Calculate expected WBTC after fees
            let fee = (btc_amount * self.bridge_fee_bps.read().into()) / 10000;
            let expected_wbtc = btc_amount - fee;
            
            // Create bridge request
            let request = BridgeRequest {
                user: caller,
                btc_amount,
                wbtc_amount: expected_wbtc,
                status: BridgeStatus::Pending,
                timestamp: starknet::get_block_timestamp(),
                auto_deposit,
            };
            
            self.bridge_requests.entry(btc_tx_hash).write(request);
            
            let current_pending = self.pending_deposits.entry(caller).read();
            self.pending_deposits.entry(caller).write(current_pending + expected_wbtc);
            
            // TODO: Call Atomiq gateway to initiate bridge
            
            self.emit(BridgeInitiated {
                user: caller,
                tx_hash: btc_tx_hash,
                btc_amount,
                expected_wbtc,
                auto_deposit,
            });
        }

        fn complete_bridge(
            ref self: ContractState,
            btc_tx_hash: felt252,
            wbtc_amount: u256,
        ) {
            // Verify caller is authorized Atomiq relayer
            let caller = get_caller_address();
            assert!(caller == self.atomiq_relayer.read(), "{}", UNAUTHORIZED);
            
            let mut request = self.bridge_requests.entry(btc_tx_hash).read();
            assert!(request.status == BridgeStatus::Pending, "{}", INVALID_STATUS);
            
            // Call Atomiq gateway to complete bridge and receive WBTC
            let gateway = IAtomiqGatewayDispatcher {
                contract_address: self.atomiq_gateway.read()
            };
            
            let _this = get_contract_address();
            let success = gateway.complete_btc_bridge(
                btc_tx_hash,
                _this,
                wbtc_amount
            );
            assert!(success, "Gateway bridge failed");
            
            // Update request status
            request.status = BridgeStatus::Completed;
            request.wbtc_amount = wbtc_amount;
            self.bridge_requests.entry(btc_tx_hash).write(request);
            
            let user = request.user;
            let current_pending = self.pending_deposits.entry(user).read();
            self.pending_deposits.entry(user).write(current_pending - wbtc_amount);
            
            // If auto-deposit enabled, deposit WBTC into BitYield vault
            if request.auto_deposit {
                self._auto_deposit_to_vault(user, wbtc_amount);
            } else {
                // Transfer WBTC to user
                let wbtc = IERC20Dispatcher { contract_address: self.wbtc_token.read() };
                let success = wbtc.transfer(user, wbtc_amount);
                assert!(success, "{}", TRANSFER_FAILED);
            }
            
            self.emit(BridgeCompleted {
                user,
                tx_hash: btc_tx_hash,
                wbtc_received: wbtc_amount,
            });
        }

        fn initiate_withdrawal(
            ref self: ContractState,
            wbtc_amount: u256,
            btc_address: ByteArray,
        ) {
            let caller = get_caller_address();
            self._validate_bridge_amount(wbtc_amount);
            
            let this = get_contract_address();
            
            // Transfer WBTC from user to bridge
            let wbtc = IERC20Dispatcher { contract_address: self.wbtc_token.read() };
            let success = wbtc.transfer_from(caller, this, wbtc_amount);
            assert!(success, "{}", TRANSFER_FAILED);
            
            // TODO: Call Atomiq gateway to initiate withdrawal
            
            self.emit(WithdrawalInitiated {
                user: caller,
                wbtc_amount,
                btc_address,
            });
        }

        fn set_auto_deposit(ref self: ContractState, enabled: bool) {
            let caller = get_caller_address();
            self.auto_deposit_enabled.entry(caller).write(enabled);
        }

        fn get_bridge_request(self: @ContractState, tx_hash: felt252) -> BridgeRequest {
            self.bridge_requests.entry(tx_hash).read()
        }

        fn get_pending_deposit(self: @ContractState, user: ContractAddress) -> u256 {
            self.pending_deposits.entry(user).read()
        }

        fn is_auto_deposit_enabled(self: @ContractState, user: ContractAddress) -> bool {
            self.auto_deposit_enabled.entry(user).read()
        }

        fn update_atomiq_addresses(
            ref self: ContractState,
            gateway: ContractAddress,
            router: ContractAddress,
        ) {
            self.ownable.assert_only_owner();
            self.atomiq_gateway.write(gateway);
            self.atomiq_router.write(router);
        }

        fn update_bridge_config(
            ref self: ContractState,
            min_amount: u256,
            max_amount: u256,
            fee_bps: u32,
        ) {
            self.ownable.assert_only_owner();
            assert!(fee_bps <= 1000, "{}", ABOVE_MAXIMUM);  // Max 10% fee
            
            self.min_bridge_amount.write(min_amount);
            self.max_bridge_amount.write(max_amount);
            self.bridge_fee_bps.write(fee_bps);
        }

        fn get_bridge_config(self: @ContractState) -> (u256, u256, u32) {
            (
                self.min_bridge_amount.read(),
                self.max_bridge_amount.read(),
                self.bridge_fee_bps.read(),
            )
        }

        fn set_relayer(ref self: ContractState, relayer: ContractAddress) {
            self.ownable.assert_only_owner();
            self.atomiq_relayer.write(relayer);
        }

        fn get_relayer(self: @ContractState) -> ContractAddress {
            self.atomiq_relayer.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _validate_bridge_amount(self: @ContractState, amount: u256) {
            assert!(amount > 0, "{}", ZERO_AMOUNT);
            assert!(amount >= self.min_bridge_amount.read(), "{}", BELOW_MINIMUM);
            assert!(amount <= self.max_bridge_amount.read(), "{}", ABOVE_MAXIMUM);
        }

        fn _auto_deposit_to_vault(ref self: ContractState, user: ContractAddress, wbtc_amount: u256) {
            let vault_address = self.bityield_vault.read();
            
            // Approve vault to spend WBTC
            let wbtc = IERC20Dispatcher { contract_address: self.wbtc_token.read() };
            wbtc.approve(vault_address, wbtc_amount);
            
            // Call vault deposit function
            let vault = IVaultDispatcher { contract_address: vault_address };
            let shares = vault.deposit(wbtc_amount);
            
            // Transfer vault shares to user
            let vault_token = IERC20Dispatcher { contract_address: vault_address };
            let success = vault_token.transfer(user, shares);
            assert!(success, "{}", TRANSFER_FAILED);
            
            self.emit(AutoDepositExecuted {
                user,
                wbtc_amount,
                vault_shares: shares,
            });
        }
    }
}