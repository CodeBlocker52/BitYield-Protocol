import { 
  braavos, 
  argent,
  InjectedConnector, 
  ready 
} from "@starknet-react/core";
import { getTargetNetworks } from "~~/utils/scaffold-stark";
import { BurnerConnector } from "@scaffold-stark/stark-burner";
import scaffoldConfig from "~~/scaffold.config";
import { LAST_CONNECTED_TIME_LOCALSTORAGE_KEY } from "~~/utils/Constants";
import { supportedChains } from "~~/supportedChains";

const targetNetworks = getTargetNetworks();

export const connectors = getConnectors();

// Workaround helper function to properly disconnect with removing local storage
function withDisconnectWrapper(connector: InjectedConnector) {
  const connectorDisconnect = connector.disconnect;
  const _disconnect = (): Promise<void> => {
    localStorage.removeItem("lastUsedConnector");
    localStorage.removeItem(LAST_CONNECTED_TIME_LOCALSTORAGE_KEY);
    return connectorDisconnect();
  };
  connector.disconnect = _disconnect.bind(connector);
  return connector;
}

function getConnectors() {
  const { targetNetworks } = scaffoldConfig;

  // Base connectors for production wallets
  const connectors: InjectedConnector[] = [];

  // Check if we're on devnet
  const isDevnet = targetNetworks.some(
    (network) => (network.network as string) === "devnet",
  );

  // PRODUCTION WALLETS (Always available)
  // ArgentX - Most popular Starknet wallet
  connectors.push(argent());
  
  // Braavos - Second most popular
  connectors.push(braavos());

  // DEVELOPMENT ONLY - Burner Wallet
  if (isDevnet && !scaffoldConfig.onlyLocalBurnerWallet) {
    const burnerConnector = new BurnerConnector();
    burnerConnector.chain = supportedChains.devnet;
    connectors.push(burnerConnector as unknown as InjectedConnector);
  }

  // REMOVED: KeplrConnector (This is for Cosmos, not Starknet!)
  // REMOVED: Random sorting - Keep wallets in consistent order

  return connectors.map(withDisconnectWrapper);
}

export const appChains = targetNetworks;