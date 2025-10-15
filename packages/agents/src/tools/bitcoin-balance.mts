// src/tools/bitcoin-balance.mts

import { displayLoading, displaySuccess, displayBalance, displayTable } from '../utils/display.mts';
import type { BitcoinBalance } from '../utils/types.mts';

async function fetchBTCPrice(): Promise<number> {
  try {
    const response = await fetch('https://api.coinbase.com/v2/prices/BTC-USD/spot');
    const data = await response.json();
    return parseFloat(data.data.amount);
  } catch {
    return 42500; // Fallback price
  }
}

async function fetchBTCBalance(address: string): Promise<number> {
  try {
    const response = await fetch(`https://blockchain.info/q/addressbalance/${address}`);
    const satoshis = await response.text();
    return parseInt(satoshis) / 1e8; // Convert satoshis to BTC
  } catch {
    return 0;
  }
}

export async function fetchBitcoinBalance(): Promise<BitcoinBalance> {
  const address = process.env.BITCOIN_ADDRESS || 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh';
  
  await displayLoading('Fetching Bitcoin balance...');

  const [btcAmount, btcPrice] = await Promise.all([
    fetchBTCBalance(address),
    fetchBTCPrice(),
  ]);

  displaySuccess('Bitcoin balance fetched');

  return {
    btc_amount: btcAmount,
    usd_value: btcAmount * btcPrice,
    address,
  };
}

export async function displayBitcoinBalance(balance: BitcoinBalance): Promise<string> {
  console.log('\n🪙 Your Bitcoin Holdings:\n');
  displayBalance('BTC', balance.btc_amount, balance.usd_value);

  displayTable({
    'Amount': `${balance.btc_amount.toFixed(8)} BTC`,
    'USD Value': `$${balance.usd_value.toFixed(2)}`,
    'Address': `${balance.address.substring(0, 12)}...`,
    'Network': 'Bitcoin L1',
  });

  return `You have ${balance.btc_amount.toFixed(8)} BTC worth $${balance.usd_value.toFixed(2)}`;
}