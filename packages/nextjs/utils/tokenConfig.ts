// config/tokenConfig.ts

export interface TokenInfo {
  symbol: string;
  name: string;
  icon: string;
  decimals: number;
  tokenId?: string;
  color: string;
}

export const HEDERA_TOKENS: Record<string, TokenInfo> = {
  HBAR: {
    symbol: 'HBAR',
    name: 'Hedera Hashgraph',
    icon: 'https://cryptologos.cc/logos/hedera-hbar-logo.png',
    decimals: 8,
    tokenId: '0.0.0',
    color: '#4F46E5'
  },
  USDC: {
    symbol: 'USDC',
    name: 'USD Coin',
    icon: 'https://cryptologos.cc/logos/usd-coin-usdc-logo.png',
    decimals: 6,
    tokenId: '0.0.456858',
    color: '#2775CA'
  },
  SAUCE: {
    symbol: 'SAUCE',
    name: 'SaucerSwap Token',
    icon: 'https://saucerswap.finance/tokens/sauce.svg',
    decimals: 6,
    tokenId: '0.0.731861',
    color: '#8B5CF6'
  },
  WHBAR: {
    symbol: 'WHBAR',
    name: 'Wrapped HBAR',
    icon: 'https://cryptologos.cc/logos/hedera-hbar-logo.png',
    decimals: 8,
    tokenId: '0.0.1456986',
    color: '#6366F1'
  }
};

// Fallback token for unknown tokens
export const UNKNOWN_TOKEN: TokenInfo = {
  symbol: '?',
  name: 'Unknown Token',
  icon: 'https://via.placeholder.com/24/6B7280/FFFFFF?text=?',
  decimals: 8,
  color: '#6B7280'
};

export const getTokenInfo = (symbol: string): TokenInfo => {
  return HEDERA_TOKENS[symbol.toUpperCase()] || UNKNOWN_TOKEN;
};

// Network configurations for HashScan links
export const HEDERA_NETWORKS = {
  mainnet: {
    name: 'Mainnet',
    hashscanUrl: 'https://hashscan.io',
    chainId: '295'
  },
  testnet: {
    name: 'Testnet', 
    hashscanUrl: 'https://hashscan.io/testnet',
    chainId: '296'
  },
};

export const getHashScanUrl = (network: keyof typeof HEDERA_NETWORKS = 'testnet') => {
  return HEDERA_NETWORKS[network].hashscanUrl;
};