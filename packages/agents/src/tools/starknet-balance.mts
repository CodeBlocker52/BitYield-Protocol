// src/tools/starknet-balance.mts

import { Contract, RpcProvider } from 'starknet';
import { displayLoading, displaySuccess, displayBalance } from '../utils/display.mts';
import type { Asset } from '../utils/types.mts';

const STARKNET_RPC = 'https://starknet-sepolia.public.blastapi.io/rpc/v0_7';
const provider = new RpcProvider({ nodeUrl: STARKNET_RPC });

const CONTRACTS = {
  WBTC: '0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac',
  STRK: '0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f05fc6923d',
  USDC: '0x053c91253bc9682c04929ca02ed00b130b7eb527852b735490e8d2dc12e23fab',
  ETH: '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7',
};

const ERC20_ABI = [
  {
    name: 'balanceOf',
    type: 'function',
    inputs: [{ name: 'account', type: 'felt' }],
    outputs: [{ name: 'balance', type: 'Uint256' }],
    stateMutability: 'view',
  },
];

async function getBalance(tokenAddress: string, userAddress: string): Promise<number> {
  try {
    const contract = new Contract(ERC20_ABI, tokenAddress, provider);
    const result = await contract.balanceOf(userAddress);
    const balance = BigInt(result.toString());
    return Number(balance) / 1e8; // WBTC has 8 decimals
  } catch {
    return 0;
  }
}

export async function fetchStarknetBalance(): Promise<Asset[]> {
  const userAddress = process.env.STARKNET_ADDRESS || '0x0';
  
  await displayLoading('Fetching Starknet balances...');

  const [wbtc, strk, usdc, eth] = await Promise.all([
    getBalance(CONTRACTS.WBTC, userAddress),
    getBalance(CONTRACTS.STRK, userAddress),
    getBalance(CONTRACTS.USDC, userAddress),
    getBalance(CONTRACTS.ETH, userAddress),
  ]);

  displaySuccess('Balances fetched');

  return [
    { symbol: 'WBTC', amount: wbtc, chain: 'Starknet' },
    { symbol: 'STRK', amount: strk, chain: 'Starknet' },
    { symbol: 'USDC', amount: usdc, chain: 'Starknet' },
    { symbol: 'ETH', amount: eth, chain: 'Starknet' },
  ].filter(a => a.amount > 0);
}

export async function displayStarknetBalance(assets: Asset[]): Promise<Asset[]> {
  console.log('\n📊 Your Starknet Assets:\n');
  assets.forEach(asset => {
    displayBalance(asset.symbol, asset.amount, asset.chain);
  });
  return assets;
}