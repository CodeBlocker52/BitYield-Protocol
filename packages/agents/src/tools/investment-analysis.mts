// src/tools/investment-analysis.mts

import { Contract, RpcProvider } from 'starknet';
import { displayLoading, displaySuccess, displayTable } from '../utils/display.mts';
import type { InvestmentAnalysis } from '../utils/types.mts';

const provider = new RpcProvider({
  nodeUrl: 'https://starknet-sepolia.public.blastapi.io/rpc/v0_7',
});

const VAULT_ADDRESS = '0x06552bc669d3a53c7223ae7d0d5f47613f5da4fb318f21e5f596cc8a791a3f90';
const VESU_ADDRESS = '0x0096b181aba9febca459591efdf27b885b3f8096b42f5f1f805fbd9bee65b75b';
const TROVES_ADDRESS = '0x0722c6917ff0ac4e298bfdeb409001d3bac6df3b72f338d63d075a6f614a4910';

const VAULT_ABI = [
  {
    name: 'total_assets',
    type: 'function',
    inputs: [],
    outputs: [{ type: 'Uint256' }],
    stateMutability: 'view',
  },
  {
    name: 'get_config',
    type: 'function',
    inputs: [],
    outputs: [{ type: 'VaultConfig' }],
    stateMutability: 'view',
  },
];

async function getVaultTVL(): Promise<number> {
  try {
    const contract = new Contract(VAULT_ABI, VAULT_ADDRESS, provider);
    const totalAssets = await contract.total_assets();
    return Number(totalAssets.toString()) / 1e8; // WBTC has 8 decimals
  } catch {
    return 0;
  }
}

async function calculateYields(): Promise<{ vesu: number; troves: number }> {
  // Fetch real APY data from DeFiLlama or protocol APIs
  try {
    const response = await fetch('https://yields.llama.fi/pools');
    const data = await response.json();
    
    // Find Vesu and Troves pools
    const vesuPool = data.data.find((p: any) => 
      p.project === 'vesu' && p.chain === 'Starknet'
    );
    const trovesPool = data.data.find((p: any) => 
      p.project === 'troves' && p.chain === 'Starknet'
    );
    
    return {
      vesu: vesuPool?.apy / 100 || 0.042,
      troves: trovesPool?.apy / 100 || 0.065,
    };
  } catch {
    return { vesu: 0.042, troves: 0.065 }; // Fallback
  }
}

export async function analyzeInvestment(btcAmount: number): Promise<InvestmentAnalysis> {
  await displayLoading('Analyzing market conditions...');

  const [tvl, yields] = await Promise.all([
    getVaultTVL(),
    calculateYields(),
  ]);

  // Calculate optimal allocation
  const vesuWeight = 0.7; // 70%
  const trovesWeight = 0.3; // 30%
  
  const weightedYield = (yields.vesu * vesuWeight) + (yields.troves * trovesWeight);
  const protocolFee = 0.015;
  const netYield = weightedYield - protocolFee;

  displaySuccess('Analysis complete');

  return {
    investable_amount: btcAmount,
    recommended_yield: netYield,
    vesu_allocation_pct: vesuWeight * 100,
    troves_allocation_pct: trovesWeight * 100,
    vault_address: VAULT_ADDRESS,
  };
}

export async function displayInvestmentAnalysis(analysis: InvestmentAnalysis): Promise<string> {
  console.log('\n💹 Investment Analysis\n');

  const vesuAmount = (analysis.investable_amount * analysis.vesu_allocation_pct) / 100;
  const trovesAmount = analysis.investable_amount - vesuAmount;

  displayTable({
    'Investment Amount': `${analysis.investable_amount.toFixed(4)} BTC`,
    'Expected Yield': `${(analysis.recommended_yield * 100).toFixed(2)}%`,
    'Vesu Allocation': `${vesuAmount.toFixed(4)} BTC (${analysis.vesu_allocation_pct}%)`,
    'Troves Allocation': `${trovesAmount.toFixed(4)} BTC (${analysis.troves_allocation_pct}%)`,
    'Vault': `${analysis.vault_address.substring(0, 10)}...`,
  });

  return `Invest ${analysis.investable_amount} BTC for ${(analysis.recommended_yield * 100).toFixed(2)}% APY. Proceed?`;
}