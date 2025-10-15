use starknet::ContractAddress;

#[starknet::interface]
pub trait IMockTrovesStrategy<TContractState> {
    // Strategy functions
    fn deposit(ref self: TContractState, assets: u256) -> u256;
    fn withdraw(ref self: TContractState, shares: u256, receiver: ContractAddress) -> u256;
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn total_assets(self: @TContractState) -> u256;
    fn share_price(self: @TContractState) -> u256;
    
    // Mock helpers
    fn set_yield(ref self: TContractState, yield_amount: u256);
}

#[starknet::contract]
mod MockTrovesStrategy {
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Map, StoragePathEntry
    };

    #[storage]
    struct Storage {
        asset: ContractAddress,
        user_shares: Map<ContractAddress, u256>,
        total_shares: u256,
        total_deposited: u256,
        accumulated_yield: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Deposit: Deposit,
        Withdraw: Withdraw,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Deposit {
        #[key]
        pub user: ContractAddress,
        pub assets: u256,
        pub shares: u256,
    }

    #[derive(Drop, starknet::Event)]
    pub struct Withdraw {
        #[key]
        pub user: ContractAddress,
        pub assets: u256,
        pub shares: u256,
    }

    #[constructor]
    fn constructor(ref self: ContractState, asset: ContractAddress) {
        self.asset.write(asset);
        self.total_shares.write(0);
        self.total_deposited.write(0);
        self.accumulated_yield.write(0);
    }

    #[abi(embed_v0)]
    impl MockTrovesStrategyImpl of super::IMockTrovesStrategy<ContractState> {
        fn deposit(ref self: ContractState, assets: u256) -> u256 {
            let caller = get_caller_address();
            let this = get_contract_address();
            
            // Transfer assets from caller
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            asset_token.transfer_from(caller, this, assets);
            
            // Calculate shares (considering yield)
            let shares = self._calculate_shares_from_assets(assets);
            
            // Update user shares
            let current_shares = self.user_shares.entry(caller).read();
            self.user_shares.entry(caller).write(current_shares + shares);
            
            // Update totals
            let current_total_shares = self.total_shares.read();
            self.total_shares.write(current_total_shares + shares);
            
            let current_deposited = self.total_deposited.read();
            self.total_deposited.write(current_deposited + assets);
            
            self.emit(Deposit { user: caller, assets, shares });
            
            shares
        }

        fn withdraw(ref self: ContractState, shares: u256, receiver: ContractAddress) -> u256 {
            let caller = get_caller_address();
            
            // Check user has enough shares
            let user_shares = self.user_shares.entry(caller).read();
            assert(user_shares >= shares, 'Insufficient shares');
            
            // Calculate assets including yield
            let assets = self._calculate_assets_from_shares(shares);
            
            // Update user shares
            self.user_shares.entry(caller).write(user_shares - shares);
            
            // Update totals
            let current_total_shares = self.total_shares.read();
            self.total_shares.write(current_total_shares - shares);
            
            let current_deposited = self.total_deposited.read();
            if assets <= current_deposited {
                self.total_deposited.write(current_deposited - assets);
            } else {
                self.total_deposited.write(0);
            }
            
            // Transfer assets to receiver
            let asset_token = IERC20Dispatcher { contract_address: self.asset.read() };
            asset_token.transfer(receiver, assets);
            
            self.emit(Withdraw { user: caller, assets, shares });
            
            assets
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.user_shares.entry(account).read()
        }

        fn total_assets(self: @ContractState) -> u256 {
            self.total_deposited.read() + self.accumulated_yield.read()
        }

        fn share_price(self: @ContractState) -> u256 {
            let total_shares = self.total_shares.read();
            if total_shares == 0 {
                100000000 // 1.0 with 8 decimals
            } else {
                let total_assets = self.total_assets();
                (total_assets * 100000000) / total_shares
            }
        }

        fn set_yield(ref self: ContractState, yield_amount: u256) {
            let current_yield = self.accumulated_yield.read();
            self.accumulated_yield.write(current_yield + yield_amount);
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _calculate_shares_from_assets(self: @ContractState, assets: u256) -> u256 {
            let total_shares = self.total_shares.read();
            let total_assets = self.total_assets();
            
            if total_shares == 0 || total_assets == 0 {
                assets // 1:1 for first deposit
            } else {
                (assets * total_shares) / total_assets
            }
        }

        fn _calculate_assets_from_shares(self: @ContractState, shares: u256) -> u256 {
            let total_shares = self.total_shares.read();
            
            if total_shares == 0 {
                0
            } else {
                (shares * self.total_assets()) / total_shares
            }
        }
    }
}