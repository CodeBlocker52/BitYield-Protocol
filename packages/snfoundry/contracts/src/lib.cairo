

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
    pub mod VesuAdapter;
    pub mod TrovesAdapter;
    pub mod AtomiqBridge;
    pub mod StrategyManager;


// ===== MOCKS (Testing Only) =====
#[cfg(test)]
pub mod mocks {
    pub mod MockWBTC;
    pub mod MockVToken;
    pub mod MockAtomiqGateway;
}

// ===== TESTS =====
#[cfg(test)]
pub mod tests {
    pub mod test_vault;
    pub mod test_vesu_adapter;
    pub mod test_troves_adapter;
    pub mod test_strategy_manager;
    pub mod test_atomiq_bridge;
    pub mod test_integration;
}