/// MockAtomiqGateway - Mock implementation of Atomiq's Bitcoin bridge gateway
/// For testing purposes only - simulates BTC to WBTC bridging

#[starknet::contract]
mod MockAtomiqGateway {
    use starknet::{ContractAddress, get_contract_address, get_caller_address};
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};

    #[storage]
    struct Storage {
        wbtc_token: ContractAddress,
        authorized_relayer: ContractAddress,
        processed_bridges: LegacyMap<felt252, bool>,  // btc_tx_hash -> processed
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        BridgeProcessed: BridgeProcessed,
        WithdrawalProcessed: WithdrawalProcessed,
    }

    #[derive(Drop, starknet::Event)]
    struct BridgeProcessed {
        #[key]
        btc_tx_hash: felt252,
        recipient: ContractAddress,
        amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    struct WithdrawalProcessed {
        sender: ContractAddress,
        amount: u256,
        btc_address: ByteArray,
    }

    mod Errors {
        const UNAUTHORIZED: felt252 = 'Unauthorized relayer';
        const ALREADY_PROCESSED: felt252 = 'Bridge already processed';
        const TRANSFER_FAILED: felt252 = 'WBTC transfer failed';
        const ZERO_AMOUNT: felt252 = 'Amount must be > 0';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        wbtc_token: ContractAddress,
        authorized_relayer: ContractAddress,
    ) {
        self.wbtc_token.write(wbtc_token);
        self.authorized_relayer.write(authorized_relayer);
    }

    #[abi(embed_v0)]
    impl MockAtomiqGatewayImpl of super::IMockAtomiqGateway<ContractState> {
        /// Simulate completing a BTC to WBTC bridge
        /// In production, this would verify Bitcoin transaction and mint WBTC
        fn complete_btc_bridge(
            ref self: ContractState,
            btc_tx_hash: felt252,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            // Verify caller is authorized relayer
            assert(
                get_caller_address() == self.authorized_relayer.read(),
                Errors::UNAUTHORIZED
            );
            
            // Check not already processed
            assert(
                !self.processed_bridges.read(btc_tx_hash),
                Errors::ALREADY_PROCESSED
            );
            
            assert(amount > 0, Errors::ZERO_AMOUNT);
            
            // Mark as processed
            self.processed_bridges.write(btc_tx_hash, true);
            
            // In real Atomiq: This would mint WBTC based on verified BTC deposit
            // In mock: Transfer WBTC from gateway's balance (must be pre-funded)
            let wbtc = IERC20Dispatcher { contract_address: self.wbtc_token.read() };
            let success = wbtc.transfer(recipient, amount);
            assert(success, Errors::TRANSFER_FAILED);
            
            self.emit(BridgeProcessed {
                btc_tx_hash,
                recipient,
                amount,
            });
            
            true
        }

        /// Simulate WBTC to BTC withdrawal
        /// In production, this would burn WBTC and unlock BTC on L1
        fn initiate_btc_withdrawal(
            ref self: ContractState,
            sender: ContractAddress,
            amount: u256,
            btc_address: ByteArray,
        ) -> bool {
            assert(amount > 0, Errors::ZERO_AMOUNT);
            
            // In real Atomiq: Would burn WBTC and unlock BTC
            // In mock: Just hold the WBTC (assuming it was already transferred)
            
            self.emit(WithdrawalProcessed {
                sender,
                amount,
                btc_address,
            });
            
            true
        }

        /// Check if a bridge has been processed
        fn is_bridge_processed(self: @ContractState, btc_tx_hash: felt252) -> bool {
            self.processed_bridges.read(btc_tx_hash)
        }

        /// Get the WBTC token address
        fn get_wbtc_token(self: @ContractState) -> ContractAddress {
            self.wbtc_token.read()
        }

        /// Get authorized relayer address
        fn get_relayer(self: @ContractState) -> ContractAddress {
            self.authorized_relayer.read()
        }
    }
}

#[starknet::interface]
trait IMockAtomiqGateway<TContractState> {
    fn complete_btc_bridge(
        ref self: TContractState,
        btc_tx_hash: felt252,
        recipient: ContractAddress,
        amount: u256,
    ) -> bool;
    fn initiate_btc_withdrawal(
        ref self: TContractState,
        sender: ContractAddress,
        amount: u256,
        btc_address: ByteArray,
    ) -> bool;
    fn is_bridge_processed(self: @TContractState, btc_tx_hash: felt252) -> bool;
    fn get_wbtc_token(self: @TContractState) -> ContractAddress;
    fn get_relayer(self: @TContractState) -> ContractAddress;
}