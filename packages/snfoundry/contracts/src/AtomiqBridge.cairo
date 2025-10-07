/// AtomiqBridge - Integration with Atomiq Protocol for BTC <-> WBTC bridging
/// This contract facilitates seamless Bitcoin L1 to WBTC conversion on Starknet
/// Reference: https://github.com/atomiqlabs/atomiq-contracts-starknet

#[starknet::contract]
mod AtomiqBridge {
    use starknet::{ContractAddress, get_contract_address, get_caller_address};
    use openzeppelin::access::ownable::{OwnableComponent};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use bityield_protocol::mocks::MockAtomiqGateway::{IMockAtomiqGatewayDispatcher, IMockAtomiqGatewayDispatcherTrait};
    use bityield_protocol::interfaces::IBitYieldVault::{IBitYieldVaultDispatcher, IBitYieldVaultDispatcherTrait};

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        
        // Atomiq protocol contract addresses
        atomiq_gateway: ContractAddress,
        atomiq_router: ContractAddress,
        atomiq_relayer: ContractAddress,  // Authorized relayer address
        
        // WBTC token on Starknet
        wbtc_token: ContractAddress,
        
        // BitYield vault for auto-deposit
        bityield_vault: ContractAddress,
        
        // Bridge transaction tracking
        bridge_requests: LegacyMap<felt252, BridgeRequest>,  // tx_hash -> request
        pending_deposits: LegacyMap<ContractAddress, u256>,  // user -> pending amount
        
        // Fee configuration
        bridge_fee_bps: u32,  // basis points
        min_bridge_amount: u256,
        max_bridge_amount: u256,
        
        // Auto-deposit configuration
        auto_deposit_enabled: LegacyMap<ContractAddress, bool>,
    }

    #[derive(Drop, Copy, Serde, starknet::Store)]
    struct BridgeRequest {
        user: ContractAddress,
        btc_amount: u256,
        wbtc_amount: u256,
        status: BridgeStatus,
        timestamp: u64,
        auto_deposit: bool,
    }

    #[derive(Drop, Copy, Serde, starknet::Store, PartialEq)]
    enum BridgeStatus {
        Pending,
        Confirmed,
        Completed,
        Failed,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        
        BridgeInitiated: BridgeInitiated,
        BridgeCompleted: BridgeCompleted,
        AutoDepositExecuted: AutoDepositExecuted,
        WithdrawalInitiated: WithdrawalInitiated,
    }

    #[derive(Drop, starknet::Event)]
    struct BridgeInitiated {
        #[key]
        user: ContractAddress,
        #[key]
        tx_hash: felt252,
        btc_amount: u256,
        expected_wbtc: u256,
        auto_deposit: bool,
    }

    #[derive(Drop, starknet::Event)]
    struct BridgeCompleted {
        #[key]
        user: ContractAddress,
        #[key]
        tx_hash: felt252,
        wbtc_received: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct AutoDepositExecuted {
        #[key]
        user: ContractAddress,
        wbtc_amount: u256,
        vault_shares: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct WithdrawalInitiated {
        #[key]
        user: ContractAddress,
        wbtc_amount: u256,
        btc_address: ByteArray,
    }

    mod Errors {
        const ZERO_ADDRESS: felt252 = 'Zero address not allowed';
        const ZERO_AMOUNT: felt252 = 'Amount must be greater than 0';
        const BELOW_MINIMUM: felt252 = 'Below minimum bridge amount';
        const ABOVE_MAXIMUM: felt252 = 'Above maximum bridge amount';
        const REQUEST_NOT_FOUND: felt252 = 'Bridge request not found';
        const INVALID_STATUS: felt252 = 'Invalid request status';
        const UNAUTHORIZED: felt252 = 'Unauthorized caller';
        const TRANSFER_FAILED: felt252 = 'Token transfer failed';
    }

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
        /// Initiate BTC to WBTC bridge transaction
        /// @param btc_tx_hash: Bitcoin transaction hash
        /// @param btc_amount: Amount of BTC to bridge (in satoshis)
        /// @param auto_deposit: Whether to auto-deposit WBTC into BitYield vault
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
            
            self.bridge_requests.write(btc_tx_hash, request);
            self.pending_deposits.write(caller, self.pending_deposits.read(caller) + expected_wbtc);
            
            // TODO: Call Atomiq gateway to initiate bridge
            // This would involve:
            // 1. Verifying Bitcoin transaction on L1
            // 2. Locking BTC in Atomiq bridge
            // 3. Minting WBTC on Starknet
            
            self.emit(BridgeInitiated {
                user: caller,
                tx_hash: btc_tx_hash,
                btc_amount,
                expected_wbtc,
                auto_deposit,
            });
        }

        /// Complete bridge transaction (called by Atomiq relayer)
        /// @param btc_tx_hash: Bitcoin transaction hash
        /// @param wbtc_amount: Actual WBTC amount received
        fn complete_bridge(
            ref self: ContractState,
            btc_tx_hash: felt252,
            wbtc_amount: u256,
        ) {
            // Verify caller is authorized Atomiq relayer
            let caller = get_caller_address();
            assert(caller == self.atomiq_relayer.read(), Errors::UNAUTHORIZED);
            
            let mut request = self.bridge_requests.read(btc_tx_hash);
            assert(request.status == BridgeStatus::Pending, Errors::INVALID_STATUS);
            
            // Call Atomiq gateway to complete bridge and receive WBTC
            let gateway = IMockAtomiqGatewayDispatcher {
                contract_address: self.atomiq_gateway.read()
            };
            
            let this = get_contract_address();
            let success = gateway.complete_btc_bridge(
                btc_tx_hash,
                this,  // WBTC sent to this contract
                wbtc_amount
            );
            assert(success, 'Gateway bridge failed');
            
            // Update request status
            request.status = BridgeStatus::Completed;
            request.wbtc_amount = wbtc_amount;
            self.bridge_requests.write(btc_tx_hash, request);
            
            let user = request.user;
            self.pending_deposits.write(user, self.pending_deposits.read(user) - wbtc_amount);
            
            // If auto-deposit enabled, deposit WBTC into BitYield vault
            if request.auto_deposit {
                self._auto_deposit_to_vault(user, wbtc_amount);
            } else {
                // Transfer WBTC to user
                let wbtc = IERC20Dispatcher { contract_address: self.wbtc_token.read() };
                let success = wbtc.transfer(user, wbtc_amount);
                assert(success, Errors::TRANSFER_FAILED);
            }
            
            self.emit(BridgeCompleted {
                user,
                tx_hash: btc_tx_hash,
                wbtc_received: wbtc_amount,
            });
        }

        /// Initiate WBTC to BTC withdrawal
        /// @param wbtc_amount: Amount of WBTC to bridge back to Bitcoin
        /// @param btc_address: Bitcoin address to receive funds
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
            assert(success, Errors::TRANSFER_FAILED);
            
            // TODO: Call Atomiq gateway to initiate withdrawal
            // This would involve:
            // 1. Burning WBTC on Starknet
            // 2. Unlocking BTC on L1
            // 3. Sending BTC to provided address
            
            self.emit(WithdrawalInitiated {
                user: caller,
                wbtc_amount,
                btc_address,
            });
        }

        /// Enable/disable auto-deposit for user
        fn set_auto_deposit(ref self: ContractState, enabled: bool) {
            let caller = get_caller_address();
            self.auto_deposit_enabled.write(caller, enabled);
        }

        /// Get bridge request details
        fn get_bridge_request(self: @ContractState, tx_hash: felt252) -> BridgeRequest {
            self.bridge_requests.read(tx_hash)
        }

        /// Get pending deposit amount for user
        fn get_pending_deposit(self: @ContractState, user: ContractAddress) -> u256 {
            self.pending_deposits.read(user)
        }

        /// Check if auto-deposit is enabled for user
        fn is_auto_deposit_enabled(self: @ContractState, user: ContractAddress) -> bool {
            self.auto_deposit_enabled.read(user)
        }

        /// Update Atomiq protocol addresses
        fn update_atomiq_addresses(
            ref self: ContractState,
            gateway: ContractAddress,
            router: ContractAddress,
        ) {
            self.ownable.assert_only_owner();
            self.atomiq_gateway.write(gateway);
            self.atomiq_router.write(router);
        }

        /// Update bridge configuration
        fn update_bridge_config(
            ref self: ContractState,
            min_amount: u256,
            max_amount: u256,
            fee_bps: u32,
        ) {
            self.ownable.assert_only_owner();
            assert(fee_bps <= 1000, Errors::ABOVE_MAXIMUM);  // Max 10% fee
            
            self.min_bridge_amount.write(min_amount);
            self.max_bridge_amount.write(max_amount);
            self.bridge_fee_bps.write(fee_bps);
        }

        /// Get bridge configuration
        fn get_bridge_config(self: @ContractState) -> (u256, u256, u32) {
            (
                self.min_bridge_amount.read(),
                self.max_bridge_amount.read(),
                self.bridge_fee_bps.read(),
            )
        }

        /// Set authorized relayer (owner only)
        fn set_relayer(ref self: ContractState, relayer: ContractAddress) {
            self.ownable.assert_only_owner();
            self.atomiq_relayer.write(relayer);
        }

        /// Get authorized relayer address
        fn get_relayer(self: @ContractState) -> ContractAddress {
            self.atomiq_relayer.read()
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _validate_bridge_amount(self: @ContractState, amount: u256) {
            assert(amount > 0, Errors::ZERO_AMOUNT);
            assert(amount >= self.min_bridge_amount.read(), Errors::BELOW_MINIMUM);
            assert(amount <= self.max_bridge_amount.read(), Errors::ABOVE_MAXIMUM);
        }

        fn _auto_deposit_to_vault(ref self: ContractState, user: ContractAddress, wbtc_amount: u256) {
            let vault_address = self.bityield_vault.read();
            
            // Approve vault to spend WBTC
            let wbtc = IERC20Dispatcher { contract_address: self.wbtc_token.read() };
            wbtc.approve(vault_address, wbtc_amount);
            
            // Call vault deposit function
            let vault = IBitYieldVaultDispatcher { contract_address: vault_address };
            let shares = vault.deposit(wbtc_amount);
            
            // Transfer vault shares to user
            let vault_token = IERC20Dispatcher { contract_address: vault_address };
            let success = vault_token.transfer(user, shares);
            assert(success, Errors::TRANSFER_FAILED);
            
            self.emit(AutoDepositExecuted {
                user,
                wbtc_amount,
                vault_shares: shares,
            });
        }
    }
}

#[starknet::interface]
trait IAtomiqBridge<TContractState> {
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

