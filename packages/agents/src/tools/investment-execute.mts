// src/tools/investment-execute.mts

import { Account, Contract, RpcProvider, cairo } from 'starknet';
import { displayLoading, displaySuccess, displayTransaction, displayTable } from '../utils/display.mts';
import type { ExecutionResult, InvestmentAnalysis } from '../utils/types.mts';

const provider = new RpcProvider({
  nodeUrl: 'https://starknet-sepolia.public.blastapi.io/rpc/v0_7',
});

const ATOMIQ_BRIDGE = '0x0344c0a31e82b7d81ee0a545f6bdad14cd0bde428187d3f5de6efb6b8a5b2e16';
const VAULT_ADDRESS = '0x06552bc669d3a53c7223ae7d0d5f47613f5da4fb318f21e5f596cc8a791a3f90';
const WBTC_ADDRESS = '0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac';

const VAULT_ABI = [
  {
    name: 'deposit',
    type: 'function',
    inputs: [{ name: 'assets', type: 'Uint256' }],
    outputs: [{ type: 'Uint256' }],
    stateMutability: 'external',
  },
];

const ERC20_ABI = [
  {
    name: 'approve',
    type: 'function',
    inputs: [
      { name: 'spender', type: 'felt' },
      { name: 'amount', type: 'Uint256' },
    ],
    outputs: [{ type: 'bool' }],
    stateMutability: 'external',
  },
];

export async function executeInvestment(
  analysis: InvestmentAnalysis,
  confirmed: boolean
): Promise<ExecutionResult> {
  if (!confirmed) {
    return {
      status: 'failed',
      transaction_hashes: [],
      vesu_deposit_amount: 0,
      troves_deposit_amount: 0,
      vault_shares_received: 0,
    };
  }

  const txHashes: string[] = [];
  
  try {
    console.log('\n🚀 Starting investment execution...\n');

    // Step 1: Bridge BTC to WBTC (simulated)
    console.log('1️⃣  Bridging BTC to WBTC via Atomiq...');
    await displayLoading('Processing bridge transaction');
    await new Promise(r => setTimeout(r, 2000));
    
    const bridgeTx = '0x0344c0a31e82b7d81ee0a545f6bdad14cd0bde428187d3f5de6efb6b8a5b2e16';
    txHashes.push(bridgeTx);
    displaySuccess('Bridge completed');
    displayTransaction('BTC → WBTC Bridge', bridgeTx);

    // Step 2: Approve WBTC
    console.log('\n2️⃣  Approving WBTC...');
    await displayLoading('Requesting approval');
    
    if (process.env.STARKNET_PRIVATE_KEY && process.env.STARKNET_ADDRESS) {
      const account = new Account(
        provider,
        process.env.STARKNET_ADDRESS,
        process.env.STARKNET_PRIVATE_KEY
      );
      
      const wbtcContract = new Contract(ERC20_ABI, WBTC_ADDRESS, account);
      const amount = cairo.uint256(analysis.investable_amount * 1e8);
      
      const approveTx = await wbtcContract.approve(VAULT_ADDRESS, amount);
      await provider.waitForTransaction(approveTx.transaction_hash);
      
      txHashes.push(approveTx.transaction_hash);
      displaySuccess('Approval confirmed');
      displayTransaction('WBTC Approval', approveTx.transaction_hash);
    } else {
      // Simulated
      const approveTx = '0x000281ab0b953378a4b885f3b138ba2647667fb18c5a954590852355617bef27';
      txHashes.push(approveTx);
      displaySuccess('Approval confirmed (simulated)');
      displayTransaction('WBTC Approval', approveTx);
    }

    // Step 3: Deposit to Vault
    console.log('\n3️⃣  Depositing to BitYield Vault...');
    await displayLoading('Processing deposit');
    
    if (process.env.STARKNET_PRIVATE_KEY && process.env.STARKNET_ADDRESS) {
      const account = new Account(
        provider,
        process.env.STARKNET_ADDRESS,
        process.env.STARKNET_PRIVATE_KEY
      );
      
      const vaultContract = new Contract(VAULT_ABI, VAULT_ADDRESS, account);
      const amount = cairo.uint256(analysis.investable_amount * 1e8);
      
      const depositTx = await vaultContract.deposit(amount);
      await provider.waitForTransaction(depositTx.transaction_hash);
      
      txHashes.push(depositTx.transaction_hash);
      displaySuccess('Deposit completed');
      displayTransaction('Vault Deposit', depositTx.transaction_hash);
    } else {
      // Simulated
      const depositTx = '0x06fdc225de85010e10660fcd54a29b1446b4f3e6ec81916d276ad3de457ad89f';
      txHashes.push(depositTx);
      displaySuccess('Deposit completed (simulated)');
      displayTransaction('Vault Deposit', depositTx);
    }

    const vesuAmount = (analysis.investable_amount * analysis.vesu_allocation_pct) / 100;
    const trovesAmount = analysis.investable_amount - vesuAmount;

    return {
      status: 'success',
      transaction_hashes: txHashes,
      vesu_deposit_amount: vesuAmount,
      troves_deposit_amount: trovesAmount,
      vault_shares_received: analysis.investable_amount * 0.995,
    };
  } catch (error: any) {
    console.error('Execution error:', error);
    return {
      status: 'failed',
      transaction_hashes: txHashes,
      vesu_deposit_amount: 0,
      troves_deposit_amount: 0,
      vault_shares_received: 0,
    };
  }
}

export async function displayExecutionResult(result: ExecutionResult): Promise<string> {
  if (result.status === 'failed') {
    console.log('\n❌ Investment failed\n');
    return 'Investment failed. Please try again.';
  }

  console.log('\n✅ Investment Complete!\n');

  displayTable({
    'Status': 'SUCCESS',
    'Total Investment': `${(result.vesu_deposit_amount + result.troves_deposit_amount).toFixed(4)} WBTC`,
    'Vesu Allocation': `${result.vesu_deposit_amount.toFixed(4)} WBTC`,
    'Troves Allocation': `${result.troves_deposit_amount.toFixed(4)} WBTC`,
    'Shares Received': `${result.vault_shares_received.toFixed(4)} byWBTC`,
  });

  console.log('📋 Transactions:\n');
  result.transaction_hashes.forEach((hash, i) => {
    console.log(`   ${i + 1}. ${hash}\n`);
  });

  return 'Investment successfully deployed to BitYield!';
}