# BitYield Protocol - Bitcoin Native Yield Aggregator on Starknet

**BitYield Protocol** enables Bitcoin holders to earn DeFi yields on Starknet without complex bridging or wrapping processes. Single Query for Bitcoin to Starknet yield farming with automated optimization across multiple protocols.



## 🎯 Problem & Solution

### Problem
Bitcoin holders cannot easily access DeFi yields without:
- Understanding complex bridging mechanisms
- Manually wrapping BTC to WBTC
- Navigating multiple DeFi protocols
- Managing rebalancing strategies

### Solution
BitYield provides:
- **One-click Bitcoin deposits** via Atomiq integration
- **Automatic WBTC conversion** on Starknet
- **Yield optimization** across Vesu lending markets and Troves strategies
- **Automated rebalancing** via Cairo smart contracts
- **Xverse wallet integration** for seamless UX

---

## 🏗️ Architecture

<div align="center">

```
┌─────────────────────────────────────────────────────────┐
│                   Frontend (React + Starknet.js)         │
│            Xverse Wallet + Atomiq SDK Integration        │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│              Atomiq Bridge Layer (BTC → WBTC)           │
│  ┌────────────────┐         ┌──────────────────┐       │
│  │ AtomiqBridge   │◄────────► MockAtomiqGateway│       │
│  │ (Cairo)        │         │ (Testing)        │       │
│  └────────────────┘         └──────────────────┘       │
└────────────────┬────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│           BitYield Core (Cairo 2.12.0 Contracts)        │
│  ┌──────────────────────────────────────────────────┐  │
│  │         BitYieldVault.cairo (ERC-4626)           │  │
│  │  • Deposit/Withdraw with share calculations      │  │
│  │  • Fee collection (performance + management)     │  │
│  │  • Emergency pause mechanism                     │  │
│  └────────────┬─────────────────────────────────────┘  │
│               │                                          │
│  ┌────────────▼─────────────────────────────────────┐  │
│  │         StrategyManager.cairo                     │  │
│  │  • Yield optimization algorithm                   │  │
│  │  • Rebalancing with threshold triggers            │  │
│  │  • APY calculation: Σ(w_i × r_i)                 │  │
│  └────────────┬─────────────────────────────────────┘  │
│               │                                          │
│  ┌────────────▼──────────────┬──────────────────────┐  │
│  │  VesuAdapter.cairo        │ TrovesAdapter.cairo  │  │
│  │  • Multi-pool management  │ • Strategy framework │  │
│  │  • ERC-4626 vToken calls  │ • Reward harvesting  │  │
│  └───────────────────────────┴──────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────┐
│          Protocol Integration Layer (Starknet)           │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐  │
│  │   Vesu   │  │  Troves  │  │  Future Protocols    │  │
│  │ (Lending)│  │(Staking) │  │  (Expandable)        │  │
│  └──────────┘  └──────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

</div>

---

---

## 📍 Deployed Contracts (Sepolia Testnet)

| Contract | Address | Starkscan |
|----------|---------|-----------|
| **BitYieldVault** | `0x06552bc669d3a53c7223ae7d0d5f47613f5da4fb318f21e5f596cc8a791a3f90` | [View](https://sepolia.starkscan.co/contract/0x06552bc669d3a53c7223ae7d0d5f47613f5da4fb318f21e5f596cc8a791a3f90) |
| **VesuAdapter** | `0x0096b181aba9febca459591efdf27b885b3f8096b42f5f1f805fbd9bee65b75b` | [View](https://sepolia.starkscan.co/contract/0x0096b181aba9febca459591efdf27b885b3f8096b42f5f1f805fbd9bee65b75b) |
| **TrovesAdapter** | `0x0722c6917ff0ac4e298bfdeb409001d3bac6df3b72f338d63d075a6f614a4910` | [View](https://sepolia.starkscan.co/contract/0x0722c6917ff0ac4e298bfdeb409001d3bac6df3b72f338d63d075a6f614a4910) |
| **StrategyManager** | `0x06154fad2a07742aed27af28c80c1259377bdffd1ffabee5aca9b1b7690b6a57` | [View](https://sepolia.starkscan.co/contract/0x06154fad2a07742aed27af28c80c1259377bdffd1ffabee5aca9b1b7690b6a57) |
| **AtomiqBridge** | `0x030cb9c97a7bb3f4e160382ce233ffdbc623b65776ce2e08ee9806e7f9d808ff` | [View](https://sepolia.starkscan.co/contract/0x030cb9c97a7bb3f4e160382ce233ffdbc623b65776ce2e08ee9806e7f9d808ff) |

---

## 📝 Project Structure

```
BitYield-Protocol/
├── packages/
│   ├── nextjs/              # Frontend application
│   │   ├── app/             # Next.js app router pages
│   │   ├── components/      # React components
│   │   ├── contracts/       # Contract ABIs and addresses
│   │   └── public/          # Static assets
│   │
│   └── snfoundry/           # Smart contracts
│       ├── contracts/       # Cairo contracts
│       │   ├── src/         # Contract source code
│       │   └── tests/       # Contract tests
│       └── scripts-ts/      # Deployment scripts
│
├── .tool-versions           # asdf version specifications
├── package.json             # Root package config
└── README.md               # This file
```

## 📦 Contract Architecture

### Core Contracts

#### 1. **BitYieldVault.cairo**
The main ERC4626-compliant vault contract managing user deposits and withdrawals.

**Key Features:**
- ERC20 share tokens (byWBTC) representing vault ownership
- Deposit WBTC, receive byWBTC shares
- Withdraw by burning byWBTC shares
- Automated fee collection (performance + management)
- Emergency pause/unpause functionality
- Owner-controlled rebalancing

**State Variables:**
```cairo
asset: ContractAddress              // WBTC token
total_assets_deposited: u256        // Total WBTC deposited
strategy_manager: ContractAddress   // Strategy orchestration
vesu_adapter: ContractAddress       // Vesu integration
troves_adapter: ContractAddress     // Troves integration
performance_fee_bps: u32            // Performance fee (basis points)
management_fee_bps: u32             // Management fee (basis points)
fee_recipient: ContractAddress      // Fee collection address
```

**Key Functions:**
- `deposit(assets: u256) -> u256`: Deposit WBTC, receive byWBTC shares
- `withdraw(shares: u256) -> u256`: Burn shares, receive WBTC
- `total_assets() -> u256`: Total value locked (TVL)
- `rebalance(vesu_bps: u32, troves_bps: u32)`: Rebalance allocations
- `collect_fees()`: Collect accrued fees
- `emergency_withdraw()`: Pull all funds from strategies

#### 2. **VesuAdapter.cairo**
Manages deposits/withdrawals to Vesu lending pools.

**Key Features:**
- Multi-pool support (different Vesu markets)
- ERC4626 vToken integration
- Pool weight management
- Emergency withdrawal per pool

**Key Functions:**
- `add_pool(pool_id: felt252, v_token: ContractAddress)`: Add Vesu pool
- `deposit(pool_id: felt252, assets: u256) -> u256`: Deposit to pool
- `withdraw(pool_id: felt252, assets: u256) -> u256`: Withdraw from pool
- `get_total_assets() -> u256`: Total deposited across pools
- `get_pool_balance(pool_id: felt252) -> u256`: Balance in specific pool

#### 3. **TrovesAdapter.cairo**
Integration with Troves/Endurfi for liquid staking strategies.

**Features:**
- Liquid staking deposit/withdrawal
- Reward claiming and compounding
- Strategy optimization

#### 4. **StrategyManager.cairo**
Orchestrates yield optimization across protocols.

**Features:**
- APY calculation and optimization
- Automated rebalancing with threshold triggers
- Multi-protocol allocation management

---

## 👤 User Flow

### For Bitcoin Holders

```
1. Connect Xverse Wallet
   ↓
2. Initiate Bitcoin Deposit
   ↓
3. Atomiq Bridges BTC → WBTC (Starknet)
   ↓
4. User Approves WBTC to BitYield Vault
   ↓
5. Vault Deposits WBTC, Mints byWBTC Shares
   ↓
6. Vault Automatically Deploys to Vesu/Troves
   ↓
7. Yield Accrues (Lending Interest + Staking Rewards)
   ↓
8. User Withdraws: Burn byWBTC → Receive WBTC
   ↓
9. Optional: Bridge WBTC → BTC via Atomiq
```

### For Vault Operators

```
1. Monitor Pool Yields (Vesu vs Troves)
   ↓
2. Call rebalance() to Optimize Returns
   ↓
3. Collect Performance + Management Fees
   ↓
4. Emergency: Pause vault or emergency_withdraw()
```

---

## 🚀 Getting Started

### Prerequisites

This project is built using [**Scaffold-Stark 2**](https://github.com/Scaffold-Stark/scaffold-stark-2), a modern development stack for Starknet dApps.

**System Requirements:**

1. **Node.js** v18+ and **Yarn** package manager
   ```bash
   node --version  # Should be v18 or higher
   yarn --version
   ```

2. **Starknet Development Tools** (managed via asdf):
   - **Scarb** v2.12.0 (Cairo package manager)
   - **Starknet Foundry** v0.49.0 (Testing framework)
   - **Starknet Devnet** v0.4.3 (Local node)

### Installation

#### Step 1: Clone the Repository

```bash
git clone https://github.com/CodeBlocker52/BitYield-Protocol
cd BitYield-Protocol
```

#### Step 2: Install asdf Version Manager (if not already installed)

The project uses `asdf` to manage Starknet toolchain versions. This ensures everyone uses the same versions.

```bash
# Install asdf
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.0

# Add to shell profile (choose your shell)
# For bash:
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
source ~/.bashrc

# For zsh:
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.zshrc
source ~/.zshrc
```

#### Step 3: Install asdf Plugins

```bash
# Add Starknet toolchain plugins
asdf plugin add scarb
asdf plugin add starknet-foundry
asdf plugin add starknet-devnet
```

#### Step 4: Install Project Dependencies

```bash
# Install Starknet toolchain versions (reads from .tool-versions)
asdf install

# Verify installations
scarb --version          # Should show: scarb 2.12.0
snforge --version        # Should show: snforge 0.49.0
starknet-devnet --version # Should show: starknet-devnet 0.4.3

# Install Node.js dependencies for frontend
cd packages/nextjs
yarn install

# Install Node.js dependencies for contracts (if needed)
cd ../snfoundry
yarn install
```

---

## 🔨 Building & Testing Contracts

### Build Contracts

```bash
cd packages/snfoundry/contracts
scarb build
```


### Run Tests

The project includes comprehensive test coverage (92 tests covering all contracts).

```bash
# From contracts directory
cd packages/snfoundry/contracts
snforge test
```



### Run Specific Tests

```bash
# Test specific contract
snforge test test_vault

# Test with verbose output
snforge test -vvv

# Test with gas profiling
snforge test --detailed-resources
```

### Test Coverage

```bash
snforge test --coverage
```

---

## 🌐 Running the Frontend

### Development Mode

```bash
cd packages/nextjs

# Start development server
yarn start
```

Visit `http://localhost:3000` to see the application.



### Production Build

```bash
cd packages/nextjs

# Build for production
yarn build

# Start production server
yarn start
```



---

## 🚢 Deploying Contracts

### Deploy to Local Devnet

**Terminal 1: Start Local Node**
```bash
cd packages/snfoundry
yarn chain
```

**Terminal 2: Deploy Contracts**
```bash
cd packages/snfoundry
yarn deploy --network devnet
```

### Deploy to Sepolia Testnet

```bash
cd packages/snfoundry
yarn deploy --network sepolia
```

**Deployment Process:**
1. Deploys VesuAdapter
2. Deploys TrovesAdapter
3. Deploys StrategyManager
4. Deploys BitYieldVault
5. Deploys AtomiqBridge
6. Configures all contract addresses
7. Outputs contract addresses to console

**Save the Contract Addresses:**
After deployment, update `packages/nextjs/contracts/deployedContracts.ts` with the new addresses.

### Deploy to Mainnet

```bash
cd packages/snfoundry
yarn deploy --network mainnet
```




## 🔧 Development Workflow

### Making Changes

1. **Edit Contracts**
   ```bash
   # Contracts are in packages/snfoundry/contracts/src/
   nano packages/snfoundry/contracts/src/vault.cairo
   ```

2. **Rebuild**
   ```bash
   cd packages/snfoundry/contracts
   scarb build
   ```

3. **Run Tests**
   ```bash
   snforge test
   ```

4. **Update Frontend** (if ABI changed)
   ```bash
   cd packages/nextjs
   yarn contracts:sync
   ```

5. **Test Frontend**
   ```bash
   yarn dev
   ```

### Common Commands

```bash
# Contracts
scarb build              # Build contracts
snforge test            # Run all tests
snforge test -vvv       # Verbose test output
scarb clean             # Clean build artifacts

# Frontend
yarn dev                # Start dev server
yarn build              # Build for production
yarn start              # Start production server
yarn lint               # Run linter
yarn format             # Format code

# Full Stack
yarn chain              # Start local devnet
yarn deploy             # Deploy contracts
yarn contracts:sync     # Sync ABIs to frontend
```

---

## 📡 Interacting with Deployed Contracts

### Using the Frontend

1. **Navigate to Yield Dashboard** (`http://localhost:3000/yield`)
2. **Connect Wallet** (Argent X, Braavos, or Xverse)
3. **Approve WBTC** for vault spending
4. **Deposit WBTC** to receive byWBTC shares
5. **Monitor Yield** and rebalancing events
6. **Withdraw** by burning byWBTC shares

### Using Starkli CLI

#### Read Total Assets
```bash
starkli call \
  0x06552bc669d3a53c7223ae7d0d5f47613f5da4fb318f21e5f596cc8a791a3f90 \
  total_assets \
  --rpc https://starknet-sepolia.public.blastapi.io/rpc/v0_9
```

#### Deposit WBTC
```bash
# 1. Approve WBTC
starkli invoke \
  <WBTC_TOKEN_ADDRESS> \
  approve \
  0x06552bc669d3a53c7223ae7d0d5f47613f5da4fb318f21e5f596cc8a791a3f90 \
  u256:1000000 \
  --rpc https://starknet-sepolia.public.blastapi.io/rpc/v0_9

# 2. Deposit to vault
starkli invoke \
  0x06552bc669d3a53c7223ae7d0d5f47613f5da4fb318f21e5f596cc8a791a3f90 \
  deposit \
  u256:1000000 \
  --rpc https://starknet-sepolia.public.blastapi.io/rpc/v0_9
```

### Using Starkscan UI

Visit contract pages for UI-based interaction:
- [BitYieldVault on Starkscan](https://sepolia.starkscan.co/contract/0x06552bc669d3a53c7223ae7d0d5f47613f5da4fb318f21e5f596cc8a791a3f90)

---

## 🧪 Test Results

**Current Test Coverage: 92 Tests - All Passing ✅**

### Test Breakdown

- **Vault Tests (16)**: Deposit, withdraw, pause, fees, multi-user scenarios
- **VesuAdapter Tests (24)**: Pool management, deposits, withdrawals, balances
- **TrovesAdapter Tests (24)**: Strategy management, deposits, withdrawals, rewards
- **StrategyManager Tests (28)**: Rebalancing, yield calculation, authorization

### Key Test Scenarios

✅ **Deposit Flow**
- Zero amount rejection
- First deposit share calculation
- Multiple user deposits
- Share price consistency

✅ **Withdrawal Flow**
- Partial withdrawals
- Full withdrawals
- Insufficient shares protection

✅ **Rebalancing**
- Owner-only rebalancing
- Authorized rebalancer access
- Time-based rebalancing constraints
- Allocation optimization

✅ **Security**
- Unauthorized access prevention
- Zero address validation
- Pause mechanism
- Emergency withdrawals

---

## 🔐 Security Considerations

### Implemented

- ✅ **Reentrancy Guards**: Prevent reentrancy attacks
- ✅ **Pausable**: Emergency stop mechanism
- ✅ **Ownable**: Access control for admin functions
- ✅ **Input Validation**: Zero amount checks, address validation
- ✅ **Safe Math**: Cairo 2.0 overflow protection
- ✅ **Role-Based Access**: Separate owner and rebalancer roles



---

## 📊 Monitoring & Metrics

### On-Chain Metrics

Monitor these key metrics through the frontend dashboard:

- **TVL (Total Value Locked)**: Total WBTC deposited in vault
- **APY**: Current annual percentage yield (weighted average)
- **Allocation**: % distribution between Vesu and Troves
- **User Balance**: Your byWBTC shares and WBTC value
- **Fee Collection**: Performance and management fees accrued

### Events to Monitor

```cairo
Deposit(user, assets, shares)
Withdraw(user, assets, shares)
Rebalance(vesu_bps, troves_bps)
FeeCollected(amount, recipient)
StrategyUpdated(strategy_id, new_target)
```

---

## 🤝 Contributing

We welcome contributions! Here's how to get started:

### Development Setup

```bash
# 1. Fork and clone
git clone https://github.com/CodeBlocker52/BitYield-Protocol
cd BitYield-Protocol

# 2. Install dependencies
asdf install
cd packages/nextjs && yarn install

# 3. Create feature branch
git checkout -b feature/amazing-feature

# 4. Make changes and test
cd packages/snfoundry/contracts
scarb build
snforge test

# 5. Test frontend
cd ../../nextjs
yarn dev

# 6. Commit and push
git add .
git commit -m 'Add amazing feature'
git push origin feature/amazing-feature

# 7. Open Pull Request
```

### Coding Standards

- **Cairo**: Follow official Cairo style guide
- **TypeScript**: Use ESLint and Prettier configurations
- **Testing**: Add tests for new features
- **Documentation**: Update README and inline comments

---

## 🐛 Troubleshooting

### Common Issues

**Issue: "No version is set for command scarb"**
```bash
# Solution: Install asdf and project tools
asdf install
```

**Issue: "Module not found" in frontend**
```bash
# Solution: Reinstall dependencies
cd packages/nextjs
rm -rf node_modules yarn.lock
yarn install
```

**Issue: Tests failing after contract changes**
```bash
# Solution: Rebuild contracts
cd packages/snfoundry/contracts
scarb clean
scarb build
snforge test
```

**Issue: Frontend can't connect to contracts**
```bash
# Solution: Sync ABIs
cd packages/nextjs
yarn contracts:sync
```

---



---

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details

---

## 🔗 Resources && Links

- **Starknet**: [starknet.io](https://starknet.io)
- **Scaffold-Stark 2**: [github.com/Scaffold-Stark/scaffold-stark-2](https://github.com/Scaffold-Stark/scaffold-stark-2)
- **Vesu Protocol**: [vesu.xyz](https://vesu.xyz)
- **Troves Protocol**: [troves.app](https://troves.app)
- **Atomiq Bridge**: [atomiq.io](https://atomiq.io)
- **Cairo Book**: [cairo-book.github.io](https://cairo-book.github.io)
- **Starknet Foundry**: [foundry-rs.github.io/starknet-foundry](https://foundry-rs.github.io/starknet-foundry/)

---

## 🏆 Hackathon Submission

**Starknet Re{solve} Hackathon 2025**

### Innovation Highlights

1. **First Bitcoin-native yield aggregator** on Starknet
2. **Seamless UX** - No manual bridging/wrapping for users
3. **Automated optimization** via Cairo smart contracts
4. **Multi-protocol integration** (Vesu, Troves, Atomiq)
5. **ERC4626 compliance** for composability
6. **Comprehensive test coverage** (92 tests - 100% passing)

### Future Roadmap

-  Integrate additional Troves strategies
-  Add more Vesu lending pools
-  Implement auto-compounding
-  Advanced rebalancing algorithms (ML-based APY prediction)
-  Governance token for protocol decisions
-  Cross-chain yield opportunities (Bitcoin L2s)
-  Mobile app integration (iOS/Android)
-  Security audit and mainnet launch

---

**Built with ❤️ on Starknet using Scaffold-Stark 2**

