use starknet::ContractAddress;

#[starknet::interface]
pub trait IMockAtomiqGateway<TContractState> {
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

#[starknet::contract]
mod MockAtomiqGateway {
    use starknet::{ContractAddress, get_caller_address};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry
    };

    #[storage]
    struct Storage {
        wbtc_token: ContractAddress,
        authorized_relayer: ContractAddress,
        processed_bridges: Map<felt252, bool>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        BridgeProcessed: BridgeProcessed,
        WithdrawalProcessed: WithdrawalProcessed,
    }

    #[derive(Drop, starknet::Event)]
    pub struct BridgeProcessed {
        #[key]
        pub btc_tx_hash: felt252,
        pub recipient: ContractAddress,
        pub amount: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WithdrawalProcessed {
        #[key]
        pub sender: ContractAddress,
        pub amount: u256,
        pub btc_address: ByteArray,
    }

    // Error constants
    pub const UNAUTHORIZED: felt252 = 'Unauthorized relayer';
    pub const ALREADY_PROCESSED: felt252 = 'Bridge already processed';
    pub const TRANSFER_FAILED: felt252 = 'WBTC transfer failed';
    pub const ZERO_AMOUNT: felt252 = 'Amount must be > 0';

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
        fn complete_btc_bridge(
            ref self: ContractState,
            btc_tx_hash: felt252,
            recipient: ContractAddress,
            amount: u256,
        ) -> bool {
            // Verify caller is authorized relayer
            assert!(
                get_caller_address() == self.authorized_relayer.read(),
                "{}",
                UNAUTHORIZED
            );
            
            // Check not already processed
            assert!(
                !self.processed_bridges.entry(btc_tx_hash).read(),
                "{}",
                ALREADY_PROCESSED
            );
            
            assert!(amount > 0, "{}", ZERO_AMOUNT);
            
            // Mark as processed
            self.processed_bridges.entry(btc_tx_hash).write(true);
            
            // In real Atomiq: This would mint WBTC based on verified BTC deposit
            // In mock: Transfer WBTC from gateway's balance (must be pre-funded)
            let wbtc = IERC20Dispatcher { contract_address: self.wbtc_token.read() };
            let success = wbtc.transfer(recipient, amount);
            assert!(success, "{}", TRANSFER_FAILED);
            
            self.emit(BridgeProcessed {
                btc_tx_hash,
                recipient,
                amount,
            });
            
            true
        }

        fn initiate_btc_withdrawal(
            ref self: ContractState,
            sender: ContractAddress,
            amount: u256,
            btc_address: ByteArray,
        ) -> bool {
            assert!(amount > 0, "{}", ZERO_AMOUNT);
            
            // In real Atomiq: Would burn WBTC and unlock BTC
            // In mock: Just hold the WBTC (assuming it was already transferred)
            
            self.emit(WithdrawalProcessed {
                sender,
                amount,
                btc_address,
            });
            
            true
        }

        fn is_bridge_processed(self: @ContractState, btc_tx_hash: felt252) -> bool {
            self.processed_bridges.entry(btc_tx_hash).read()
        }

        fn get_wbtc_token(self: @ContractState) -> ContractAddress {
            self.wbtc_token.read()
        }

        fn get_relayer(self: @ContractState) -> ContractAddress {
            self.authorized_relayer.read()
        }
    }
}