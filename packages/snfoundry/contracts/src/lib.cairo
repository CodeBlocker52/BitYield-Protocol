

// ===== INTERFACES =====
pub mod interfaces {
    pub mod IERC20;
    pub mod IERC4626;
    pub mod IBitYieldVault;
    pub mod IVesuAdapter;
    pub mod ITrovesAdapter;
    pub mod IStrategyManager;
    pub mod IAtomiqBridge;
}

// ===== CONTRACTS =====

    pub mod BitYieldVault;
    pub mod VesuAdapters;
    pub mod TrovesAdapters;
    pub mod AtomiqBridge;
    pub mod StrategyManager;


// ===== MOCKS (Testing Only) =====

pub mod mocks {
    pub mod MockWBTC;
    pub mod MockVToken;
    pub mod MockAtomiqGateway;
    pub mod MockTrovesStrategy;
}
