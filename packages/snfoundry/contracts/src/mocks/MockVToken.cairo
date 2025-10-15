use starknet::ContractAddress;

#[starknet::interface]
pub trait IMockVToken<TContractState> {
    // ERC4626 interface methods
    fn asset(self: @TContractState) -> ContractAddress;
    fn total_assets(self: @TContractState) -> u256;
    fn convert_to_shares(self: @TContractState, assets: u256) -> u256;
    fn convert_to_assets(self: @TContractState, shares: u256) -> u256;
    fn deposit(ref self: TContractState, assets: u256, receiver: ContractAddress) -> u256;
    fn withdraw(
        ref self: TContractState,
        assets: u256,
        receiver: ContractAddress,
        owner: ContractAddress
    ) -> u256;
    fn max_withdraw(self: @TContractState, owner: ContractAddress) -> u256;
    
    // Mock helpers
    fn set_exchange_rate(ref self: TContractState, rate: u256);
}

#[starknet::contract]
mod MockVToken {
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::{ContractAddress, get_caller_address, get_contract_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // Expose ERC20 functionality (includes balance_of, transfer, etc.)
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    impl ERC20ImmutableConfig of ERC20Component::ImmutableConfig {
        const DECIMALS: u8 = 8_u8;
    }

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        asset_token: ContractAddress,
        total_deposited: u256,
        exchange_rate: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, asset: ContractAddress) {
        self.erc20.initializer("Mock VToken", "vMock");
        self.asset_token.write(asset);
        self.total_deposited.write(0);
        self.exchange_rate.write(1_00000000); // 1:1 initially (8 decimals)
    }

    #[abi(embed_v0)]
    impl MockVTokenImpl of super::IMockVToken<ContractState> {
        fn asset(self: @ContractState) -> ContractAddress {
            self.asset_token.read()
        }

        fn total_assets(self: @ContractState) -> u256 {
            self.total_deposited.read()
        }

        fn convert_to_shares(self: @ContractState, assets: u256) -> u256 {
            let total_supply = self.erc20.total_supply();
            let total = self.total_deposited.read();
            
            if total_supply == 0 || total == 0 {
                assets
            } else {
                (assets * total_supply) / total
            }
        }

        fn convert_to_assets(self: @ContractState, shares: u256) -> u256 {
            let total_supply = self.erc20.total_supply();
            
            if total_supply == 0 {
                0
            } else {
                (shares * self.total_deposited.read()) / total_supply
            }
        }

        fn deposit(ref self: ContractState, assets: u256, receiver: ContractAddress) -> u256 {
            let caller = get_caller_address();
            let this = get_contract_address();
            
            // Transfer assets from caller
            let asset_dispatcher = IERC20Dispatcher { contract_address: self.asset_token.read() };
            asset_dispatcher.transfer_from(caller, this, assets);
            
            // Calculate and mint shares
            let shares = self.convert_to_shares(assets);
            self.erc20.mint(receiver, shares);
            
            // Update total deposited
            let current = self.total_deposited.read();
            self.total_deposited.write(current + assets);
            
            shares
        }

        fn withdraw(
            ref self: ContractState,
            assets: u256,
            receiver: ContractAddress,
            owner: ContractAddress
        ) -> u256 {
            let shares = self.convert_to_shares(assets);
            
            // Burn shares from owner
            self.erc20.burn(owner, shares);
            
            // Transfer assets to receiver
            let asset_dispatcher = IERC20Dispatcher { contract_address: self.asset_token.read() };
            asset_dispatcher.transfer(receiver, assets);
            
            // Update total deposited
            let current = self.total_deposited.read();
            self.total_deposited.write(current - assets);
            
            shares
        }

        fn max_withdraw(self: @ContractState, owner: ContractAddress) -> u256 {
            let shares = self.erc20.balance_of(owner);
            self.convert_to_assets(shares)
        }

        fn set_exchange_rate(ref self: ContractState, rate: u256) {
            self.exchange_rate.write(rate);
        }
    }
}