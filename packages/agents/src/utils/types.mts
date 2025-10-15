// src/utils/types.mts

export interface Asset {
  symbol: string;
  amount: number;
  chain: string;
}

export interface StarknetBalance {
  assets: Asset[];
}

export interface BitcoinBalance {
  btc_amount: number;
  usd_value: number;
  address: string;
}

export interface InvestmentAnalysis {
  investable_amount: number;
  recommended_yield: number;
  vesu_allocation_pct: number;
  troves_allocation_pct: number;
  vault_address: string;
}

export interface ExecutionResult {
  status: 'success' | 'failed';
  transaction_hashes: string[];
  vesu_deposit_amount: number;
  troves_deposit_amount: number;
  vault_shares_received: number;
}

export interface ToolResponse {
  type: 'info' | 'analysis' | 'execution' | 'confirmation';
  content: string;
  data?: any;
}