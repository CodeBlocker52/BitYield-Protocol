import React, { useState, useEffect } from "react";
import {
  useAccount,
  useConnect,
  useDisconnect,
  useNetwork,
} from "@starknet-react/core";
import {
  Wallet,
  ChevronDown,
  Copy,
  ExternalLink,
  LogOut,
  Check,
  AlertCircle,
} from "lucide-react";

export default function WalletConnectButton() {
  const { address, isConnected, account } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();
  const { chain } = useNetwork();

  const [showModal, setShowModal] = useState(false);
  const [showAccountModal, setShowAccountModal] = useState(false);
  const [copied, setCopied] = useState(false);
  const [isConnecting, setIsConnecting] = useState(false);

  // Format address: 0x1234...5678
  const formatAddress = (addr: string) => {
    if (!addr) return "";
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  // Copy address to clipboard
  const copyAddress = async () => {
    if (address) {
      await navigator.clipboard.writeText(address);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  // Open block explorer
  const openExplorer = () => {
    if (address && chain) {
      const explorerUrl =
        chain.network === "mainnet"
          ? `https://starkscan.co/contract/${address}`
          : `https://sepolia.starkscan.co/contract/${address}`;
      window.open(explorerUrl, "_blank");
    }
  };

  // Handle wallet connection
  const handleConnect = async (connector: any) => {
    try {
      setIsConnecting(true);
      await connect({ connector });
      setShowModal(false);
    } catch (error) {
      console.error("Connection error:", error);
    } finally {
      setIsConnecting(false);
    }
  };

  // Handle disconnect
  const handleDisconnect = async () => {
    await disconnect();
    setShowAccountModal(false);
  };

  // Get wallet icon
  const getWalletIcon = (connectorId: string) => {
    if (connectorId.toLowerCase().includes("argent")) {
      return "🦊"; // Replace with actual ArgentX logo
    }
    if (connectorId.toLowerCase().includes("braavos")) {
      return "🛡️"; // Replace with actual Braavos logo
    }
    return "💼";
  };

  // Get network badge color
  const getNetworkColor = () => {
    if (!chain) return "badge-info";
    switch (chain.network) {
      case "mainnet":
        return "badge-success";
      case "sepolia":
        return "badge-warning";
      case "devnet":
        return "badge-error";
      default:
        return "badge-info";
    }
  };

  return (
    <>
      {/* Connect Button */}
      {!isConnected ? (
        <button
          className="btn btn-primary gap-2 cursor-pointer"
          onClick={() => setShowModal(true)}
        >
          <Wallet className="w-5 h-5" />
          Connect Wallet
        </button>
      ) : (
        /* Connected Account Button */
        <div className="dropdown dropdown-end">
          <button
            // tabIndex={0}
            className="btn btn-primary gap-2"
            onClick={() => setShowAccountModal(true)}
          >
            <div className="w-2 h-2 rounded-full bg-success animate-pulse" />
            {formatAddress(address || "")}
            <ChevronDown className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* Wallet Selection Modal */}
      {showModal && (
        <dialog className="modal modal-open">
          <div className="modal-box border border-base-300">
            <h3 className="font-bold text-2xl mb-2">Connect Wallet</h3>
            <p className="text-base-content/70 mb-6">
              Choose your preferred Starknet wallet
            </p>

            {/* Network Info */}
            {chain && (
              <div className="alert alert-info mb-4">
                <AlertCircle className="w-5 h-5" />
                <span>Network: {chain.network.toUpperCase()}</span>
              </div>
            )}

            {/* Wallet List */}
            <div className="space-y-3">
              {connectors.map((connector) => {
                const isReady = connector.available();

                return (
                  <button
                    key={connector.id}
                    onClick={() => isReady && handleConnect(connector)}
                    disabled={!isReady || isConnecting}
                    className={`btn btn-outline w-full justify-start gap-4 h-16 ${
                      !isReady ? "btn-disabled" : "hover:border-primary"
                    }`}
                  >
                    <div className="text-3xl">
                      {getWalletIcon(connector.id)}
                    </div>
                    <div className="flex-1 text-left">
                      <div className="font-semibold">{connector.name}</div>
                      {!isReady && (
                        <div className="text-xs text-error">Not installed</div>
                      )}
                      {isConnecting && (
                        <div className="text-xs text-primary">
                          Connecting...
                        </div>
                      )}
                    </div>
                    {!isReady && (
                      <ExternalLink className="w-4 h-4 text-base-content/50" />
                    )}
                  </button>
                );
              })}
            </div>

            {/* Help Text */}
            <div className="mt-6 p-4 bg-base-200 rounded-lg">
              <p className="text-sm text-base-content/70">
                <strong>Don&apos;t have a wallet?</strong>
                <br />
                Install{" "}
                <a
                  href="https://www.argent.xyz/argent-x/"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="link"
                >
                  ArgentX
                </a>{" "}
                or{" "}
                <a
                  href="https://braavos.app/"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="link"
                >
                  Braavos
                </a>
              </p>
            </div>

            {/* Close Button */}
            <div className="modal-action">
              <button
                className="btn btn-ghost"
                onClick={() => setShowModal(false)}
              >
                Close
              </button>
            </div>
          </div>
          <form method="dialog" className="modal-backdrop">
            <button onClick={() => setShowModal(false)}>close</button>
          </form>
        </dialog>
      )}

      {/* Account Details Modal */}
      {showAccountModal && isConnected && (
        <dialog className="modal modal-open">
          <div className="modal-box border border-base-300">
            <h3 className="font-bold text-2xl mb-6">Account</h3>

            {/* Network Badge */}
            <div className="flex items-center justify-between mb-6">
              <span className="text-base-content/70">Network</span>
              <div className={`badge ${getNetworkColor()} gap-2`}>
                <div className="w-2 h-2 rounded-full bg-current" />
                {chain?.network.toUpperCase()}
              </div>
            </div>

            {/* Address */}
            <div className="mb-6">
              <label className="text-sm text-base-content/70 mb-2 block">
                Address
              </label>
              <div className="flex items-center gap-2">
                <div className="flex-1 p-3 bg-base-200 rounded-lg font-mono text-sm break-all">
                  {address}
                </div>
              </div>
            </div>

            {/* Action Buttons */}
            <div className="grid grid-cols-2 gap-3 mb-6">
              <button onClick={copyAddress} className="btn btn-outline gap-2">
                {copied ? (
                  <>
                    <Check className="w-4 h-4 text-success" />
                    Copied!
                  </>
                ) : (
                  <>
                    <Copy className="w-4 h-4" />
                    Copy Address
                  </>
                )}
              </button>

              <button onClick={openExplorer} className="btn btn-outline gap-2">
                <ExternalLink className="w-4 h-4" />
                Explorer
              </button>
            </div>

            {/* Disconnect Button */}
            <button
              onClick={handleDisconnect}
              className="btn btn-error btn-outline w-full gap-2"
            >
              <LogOut className="w-4 h-4" />
              Disconnect
            </button>

            {/* Close Button */}
            <div className="modal-action">
              <button
                className="btn btn-ghost"
                onClick={() => setShowAccountModal(false)}
              >
                Close
              </button>
            </div>
          </div>
          <form method="dialog" className="modal-backdrop">
            <button onClick={() => setShowAccountModal(false)}>close</button>
          </form>
        </dialog>
      )}
    </>
  );
}
