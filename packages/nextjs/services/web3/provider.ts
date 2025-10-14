import scaffoldConfig from "~~/scaffold.config";
import {
  jsonRpcProvider,
  publicProvider,
  starknetChainId,
} from "@starknet-react/core";
import * as chains from "@starknet-react/chains";

const containsDevnet = (networks: readonly chains.Chain[]) => {
  return (
    networks.filter((it) => it.network == chains.devnet.network).length > 0
  );
};

// Get the current target network (first one in the array)
const currentNetwork = scaffoldConfig.targetNetworks[0];
const currentNetworkName = currentNetwork.network;

export const getRpcUrl = (networkName: string): string => {
  // Environment variables from .env.local
  const devnetRpcUrl = process.env.NEXT_PUBLIC_DEVNET_PROVIDER_URL;
  const sepoliaRpcUrl = process.env.NEXT_PUBLIC_SEPOLIA_PROVIDER_URL;
  const mainnetRpcUrl = process.env.NEXT_PUBLIC_MAINNET_PROVIDER_URL;

  let rpcUrl = "";

  switch (networkName) {
    case "devnet":
      rpcUrl = devnetRpcUrl || "http://127.0.0.1:5050";
      break;
    case "sepolia":
      rpcUrl =
        sepoliaRpcUrl || 
        "https://starknet-sepolia.public.blastapi.io/rpc/v0_7" || // Updated to v0_7
        "https://free-rpc.nethermind.io/sepolia-juno/v0_7";
      break;
    case "mainnet":
      rpcUrl =
        mainnetRpcUrl || 
        "https://starknet-mainnet.public.blastapi.io/rpc/v0_7" || // Updated to v0_7
        "https://free-rpc.nethermind.io/mainnet-juno/v0_7";
      break;
    default:
      console.warn(`Unknown network: ${networkName}. Defaulting to devnet.`);
      rpcUrl = "http://127.0.0.1:5050";
      break;
  }

  return rpcUrl;
};

// Get RPC URL for the current network
const rpcUrl = getRpcUrl(currentNetworkName);

// Log configuration for debugging
console.log(`🌐 Network: ${currentNetworkName}`);
console.log(`🔗 RPC URL: ${rpcUrl || "Using public provider"}`);

// Provider configuration
const provider =
  rpcUrl === "" || containsDevnet(scaffoldConfig.targetNetworks)
    ? publicProvider()
    : jsonRpcProvider({
        rpc: () => ({
          nodeUrl: rpcUrl,
          chainId: starknetChainId(currentNetwork.id),
        }),
      });

export default provider;