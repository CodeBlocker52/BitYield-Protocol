
export interface TokenInfo {
  symbol: string;
  name: string;
  icon: string;
  decimals: number;
  address?: string;
  color: string;
}

export const STARKNET_TOKENS: Record<string, TokenInfo> = {
  BTC: {
    symbol: 'BTC',
    name: 'Bitcoin',
    icon: '/bitcoin-btc-logo.svg',
    decimals: 8,
    color: '#F7931A'
  },
  WBTC: {
    symbol: 'WBTC',
    name: 'Wrapped Bitcoin',
    icon: '/wrapped-bitcoin-wbtc-logo.svg',
    decimals: 8,
    address: '0x03fe2b97c1fd336e750087d68b9b867997fd64a2661ff3ca5a7c771641e8e7ac',
    color: '#F09242'
  },
  STRK: {
    symbol: 'STRK',
    name: 'Starknet Token',
    icon: '/starknetLogo.png',
    decimals: 18,
    address: '0x04718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d',
    color: '#8B45FD'
  },
  USDC: {
    symbol: 'USDC',
    name: 'USD Coin',
    icon: '/usd-coin-usdc-logo.svg',
    decimals: 6,
    address: '0x053c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8',
    color: '#2775CA'
  },
  ETH: {
    symbol: 'ETH',
    name: 'Ethereum',
    icon: '/ethereum-eth-logo.svg',
    decimals: 18,
    address: '0x049d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7',
    color: '#627EEA'
  }
};

// Fallback token for unknown tokens
export const UNKNOWN_TOKEN: TokenInfo = {
  symbol: '?',
  name: 'Unknown Token',
  icon: '/logo.svg',
  decimals: 18,
  color: '#6B7280'
};

export const getTokenInfo = (symbol: string): TokenInfo => {
  return STARKNET_TOKENS[symbol.toUpperCase()] || UNKNOWN_TOKEN;
};

// Network configurations for Starkscan links
export const STARKNET_NETWORKS = {
  mainnet: {
    name: 'Mainnet',
    starkscanUrl: 'https://starkscan.co',
    chainId: 'SN_MAIN'
  },
  sepolia: {
    name: 'Sepolia',
    starkscanUrl: 'https://sepolia.starkscan.co',
    chainId: 'SN_SEPOLIA'
  },
  devnet: {
    name: 'Devnet',
    starkscanUrl: 'http://localhost:5050',
    chainId: 'SN_DEVNET'
  }
};

export type StarknetNetwork = keyof typeof STARKNET_NETWORKS;

export const getStarkscanUrl = (network: StarknetNetwork = 'sepolia') => {
  return STARKNET_NETWORKS[network].starkscanUrl;
};