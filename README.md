# BitYield Protocol - Bitcoin Native Yield Aggregator on Starknet

**BitYield Protocol** enables Bitcoin holders to earn DeFi yields on Starknet without complex bridging or wrapping processes. One-click Bitcoin → Starknet yield farming with automated optimization across multiple protocols.

---

## 🎯 Problem & Solution

### Problem
Bitcoin holders cannot easily access DeFi yields without:
- Understanding complex bridging mechanisms
- Manually wrapping BTC to WBTC
- Navigating multiple DeFi protocols
- Managing rebalancing strategies

### Solution
BitYield provides:
- ✅ **One-click Bitcoin deposits** via Atomiq integration
- ✅ **Automatic WBTC conversion** on Starknet
- ✅ **Yield optimization** across Vesu lending markets and Troves strategies
- ✅ **Automated rebalancing** via Cairo smart contracts
- ✅ **Xverse wallet integration** for seamless UX

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     USER INTERFACE LAYER                     │
│         (React/TypeScript + Xverse + Starknet.js)          │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                  BITCOIN BRIDGE LAYER                        │
│  ┌──────────────┐         ┌─────────────────┐              │
│  │ Xverse Wallet│◄───────►│ Atomiq Protocol │              │
│  │   (BTC L1)   │         │  (BTC→WBTC)     │              │
│  └──────────────┘         └─────────────────┘              │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│              BITYIELD CORE CONTRACTS (Cairo)                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         BitYieldVault.cairo (Main Vault)             │  │
│  │  • ERC20 Share Tokens (byWBTC)                       │  │
│  │  • Deposit/Withdraw Logic                            │  │
│  │  • Fee Collection (Performance + Management)         │  │
│  │  • Emergency Controls                                 │  │
│  └────────────┬─────────────────────────────────────────┘  │
│               │                                              │
│  ┌────────────▼─────────────────┬───────────────────────┐  │
│  │    VesuAdapter.cairo         │ TrovesAdapter.cairo   │  │
│  │  • Multi-pool management     │ • Liquid staking      │  │
│  │  • Lending deposits          │ • Strategy execution  │  │
│  │  • Interest accrual          │ • Yield compounding   │  │
│  └──────────────────────────────┴───────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                 PROTOCOL INTEGRATION LAYER                   │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │ Vesu Markets │  │    Troves    │  │  Endurfi (TBD)  │  │
│  │   (Lending)  │  │  (Staking)   │  │   (Strategies)  │  │
│  └──────────────┘  └──────────────┘  └────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

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

#### 3. **TrovesAdapter.cairo** *(To be implemented)*
Integration with Troves/Endurfi for liquid staking strategies.

**Planned Features:**
- Liquid staking deposit/withdrawal
- Reward claiming and compounding
- Strategy optimization

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

## 🚀 Installation & Setup

### Prerequisites
- **Scarb** (Cairo package manager): [Install Scarb](https://docs.swmansion.com/scarb/)
- **Starknet Foundry** (Testing framework): [Install SNFoundry](https://foundry-rs.github.io/starknet-foundry/)
- **Node.js** v18+ (for frontend integration)

### Clone Repository
```bash
git clone https://github.com/your-repo/bityield-protocol
cd bityield-protocol
```

### Install Dependencies
```bash
scarb build
```

---

## 🧪 Testing

### Run All Tests
```bash
snforge test
```

### Run Specific Test
```bash
snforge test test_deposit
```

### Run with Detailed Output
```bash
snforge test -v
```

### Test Coverage
```bash
snforge test --coverage
```

### Expected Tests
- ✅ `test_deposit`: Verify WBTC deposit and byWBTC minting
- ✅ `test_withdraw`: Verify share burning and WBTC withdrawal
- ✅ `test_total_assets`: Check TVL calculation
- ✅ `test_convert_shares_to_assets`: Test share price calculation
- ✅ `test_deposit_zero_amount`: Ensure zero deposits fail
- ✅ `test_withdraw_insufficient_shares`: Ensure insufficient balance fails
- ✅ `test_pause_unpause`: Verify emergency pause functionality

---

## 📡 Deployment

### 1. Deploy on Testnet (Sepolia)

#### Deploy Mock WBTC (for testing)
```bash
starkli declare target/dev/bityield_MockWBTC.contract_class.json --network sepolia

starkli deploy \
  <MOCK_WBTC_CLASS_HASH> \
  <YOUR_ADDRESS> \
  --network sepolia
```

#### Deploy VesuAdapter
```bash
starkli declare target/dev/bityield_VesuAdapter.contract_class.json --network sepolia

starkli deploy \
  <VESU_ADAPTER_CLASS_HASH> \
  <OWNER_ADDRESS> \
  <VAULT_ADDRESS> \
  <WBTC_ADDRESS> \
  --network sepolia
```

#### Deploy BitYieldVault
```bash
starkli declare target/dev/bityield_BitYieldVault.contract_class.json --network sepolia

starkli deploy \
  <VAULT_CLASS_HASH> \
  <OWNER_ADDRESS> \
  <WBTC_ADDRESS> \
  <STRATEGY_MANAGER_ADDRESS> \
  <VESU_ADAPTER_ADDRESS> \
  <TROVES_ADAPTER_ADDRESS> \
  <FEE_RECIPIENT_ADDRESS> \
  --network sepolia
```

### 2. Configure Adapters

#### Add Vesu Pools
```bash
starkli invoke \
  <VESU_ADAPTER_ADDRESS> \
  add_pool \
  <POOL_ID> \
  <V_TOKEN_ADDRESS> \
  --network sepolia
```

### 3. Mainnet Deployment
Replace `--network sepolia` with `--network mainnet` and use production addresses.

---

## 🔗 Frontend Integration Guide

### Install Dependencies
```bash
npm install starknet @starknet-react/core get-starknet-core
```

### Connect to Starknet
```typescript
import { connect, disconnect } from 'get-starknet-core';
import { Contract, Provider } from 'starknet';

// Connect wallet
const connectWallet = async () => {
  const starknet = await connect();
  if (!starknet) throw new Error('Wallet not found');
  await starknet.enable();
  return starknet;
};
```

### Deposit WBTC
```typescript
import BitYieldVaultABI from './abis/BitYieldVault.json';
import ERC20ABI from './abis/ERC20.json';

const depositWBTC = async (
  vaultAddress: string,
  wbtcAddress: string,
  amount: string,
  account: any
) => {
  // 1. Approve WBTC
  const wbtcContract = new Contract(ERC20ABI, wbtcAddress, account);
  const approveTx = await wbtcContract.approve(vaultAddress, amount);
  await account.waitForTransaction(approveTx.transaction_hash);

  // 2. Deposit to vault
  const vaultContract = new Contract(BitYieldVaultABI, vaultAddress, account);
  const depositTx = await vaultContract.deposit(amount);
  await account.waitForTransaction(depositTx.transaction_hash);
  
  console.log('Deposit successful!', depositTx.transaction_hash);
};
```

### Withdraw WBTC
```typescript
const withdrawWBTC = async (
  vaultAddress: string,
  shares: string,
  account: any
) => {
  const vaultContract = new Contract(BitYieldVaultABI, vaultAddress, account);
  const withdrawTx = await vaultContract.withdraw(shares);
  await account.waitForTransaction(withdrawTx.transaction_hash);
  
  console.log('Withdrawal successful!', withdrawTx.transaction_hash);
};
```

### Get User Balance
```typescript
const getUserBalance = async (
  vaultAddress: string,
  userAddress: string,
  provider: Provider
) => {
  const vaultContract = new Contract(
    BitYieldVaultABI,
    vaultAddress,
    provider
  );
  
  const shares = await vaultContract.balanceOf(userAddress);
  const assets = await vaultContract.convertToAssets(shares);
  
  return {
    shares: shares.toString(),
    assets: assets.toString(),
  };
};
```

### Get Vault TVL
```typescript
const getVaultTVL = async (
  vaultAddress: string,
  provider: Provider
) => {
  const vaultContract = new Contract(
    BitYieldVaultABI,
    vaultAddress,
    provider
  );
  
  const totalAssets = await vaultContract.total_assets();
  return totalAssets.toString();
};
```

### Example React Component
```typescript
import { useAccount, useContract } from '@starknet-react/core';
import { useState, useEffect } from 'react';

function BitYieldDashboard() {
  const { account, address } = useAccount();
  const [tvl, setTvl] = useState('0');
  const [userShares, setUserShares] = useState('0');

  const { contract: vaultContract } = useContract({
    abi: BitYieldVaultABI,
    address: VAULT_ADDRESS,
  });

  useEffect(() => {
    if (vaultContract) {
      loadData();
    }
  }, [vaultContract, address]);

  const loadData = async () => {
    const totalAssets = await vaultContract.total_assets();
    setTvl(totalAssets.toString());

    if (address) {
      const balance = await vaultContract.balanceOf(address);
      setUserShares(balance.toString());
    }
  };

  const handleDeposit = async (amount: string) => {
    if (!account) return;
    await depositWBTC(VAULT_ADDRESS, WBTC_ADDRESS, amount, account);
    await loadData();
  };

  return (
    <div>
      <h2>BitYield Protocol</h2>
      <p>Total Value Locked: {tvl} WBTC</p>
      <p>Your Shares: {userShares} byWBTC</p>
      <button onClick={() => handleDeposit('1000000')}>
        Deposit 0.01 WBTC
      </button>
    </div>
  );
}
```

---

## 🔐 Security Considerations

### Implemented
- ✅ **Reentrancy Guards**: Prevent reentrancy attacks
- ✅ **Pausable**: Emergency stop mechanism
- ✅ **Ownable**: Access control for admin functions
- ✅ **Input Validation**: Zero amount checks, address validation
- ✅ **Safe Math**: Cairo 2.0 overflow protection

### Recommended Audits
- [ ] Smart contract audit by reputable firm
- [ ] Economic model review
- [ ] Integration testing with live protocols

---

## 📊 Key Metrics & Monitoring

### On-Chain Metrics
- **TVL (Total Value Locked)**: `vault.total_assets()`
- **User Deposits**: `vault.balanceOf(user)`
- **Fee Collection**: Monitor `FeeCollected` events
- **Rebalancing Events**: Track `Rebalance` events

### Performance Metrics
- **APY (Annual Percentage Yield)**: Calculate from yield deltas
- **Sharpe Ratio**: Risk-adjusted returns
- **Allocation Breakdown**: % in Vesu vs Troves

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

---

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details

---

## 🔗 Links

- **Starknet**: [starknet.io](https://starknet.io)
- **Vesu Protocol**: [vesu.xyz](https://vesu.xyz)
- **Atomiq**: [atomiq.io](https://atomiq.io)
- **Xverse Wallet**: [xverse.app](https://xverse.app)
- **Cairo Docs**: [cairo-book.github.io](https://cairo-book.github.io)

---

## 🏆 Hackathon Submission

**Starknet Res{solve} Hackathon**

### Innovation Highlights
1. **First Bitcoin-native yield aggregator** on Starknet
2. **Seamless UX** - No manual bridging/wrapping for users
3. **Automated optimization** via Cairo smart contracts
4. **Multi-protocol integration** (Vesu, Troves, Atomiq)
5. **ERC4626 compliance** for composability

### Future Roadmap
- [ ] Integrate Troves/Endurfi strategies
- [ ] Add more Vesu pools
- [ ] Implement auto-compounding
- [ ] Advanced rebalancing algorithms (APY optimization)
- [ ] Governance token for protocol decisions
- [ ] Cross-chain yield opportunities

---

**Built with ❤️ for the Starknet Re{Solve} Hackathon 2025**
