use starknet::ContractAddress;

#[starknet::contract]
mod MockWBTC {
    use openzeppelin_token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // Expose ERC20 functions
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
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress, initial_supply: u256) {
        self.erc20.initializer("Wrapped Bitcoin", "WBTC");
        self.erc20.mint(owner, initial_supply);
    }

    // Additional test helper functions
    #[abi(embed_v0)]
    impl MockWBTCImpl of super::IMockWBTC<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            self.erc20.mint(recipient, amount);
        }

        fn burn(ref self: ContractState, account: ContractAddress, amount: u256) {
            self.erc20.burn(account, amount);
        }
    }
}

#[starknet::interface]
pub trait IMockWBTC<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn burn(ref self: TContractState, account: ContractAddress, amount: u256);
}