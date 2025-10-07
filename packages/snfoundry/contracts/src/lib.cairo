// BitYield Protocol - Main Library
// Entry point for all contracts and interfaces

// ===== INTERFACES =====
pub mod interfaces {
    pub mod IBitYieldVault;
    pub mod IVesuAdapter;
    pub mod IAtomiqBridge;
}

// ===== CONTRACTS =====

    pub mod BitYieldVault;
    pub mod VesuAdapter;
    pub mod AtomiqBridge;


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
    pub mod test_atomiq_bridge;
  
}