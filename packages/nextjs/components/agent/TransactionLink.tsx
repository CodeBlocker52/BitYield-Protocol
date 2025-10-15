import React, { useState } from "react";
import { ExternalLink, Copy, CheckCircle } from "lucide-react";
import { getStarkscanUrl, StarknetNetwork } from "../../utils/tokenConfig";

interface TransactionLinkProps {
  txHash: string;
  network?: StarknetNetwork;
  className?: string;
  showCopyButton?: boolean;
}

export const TransactionLink: React.FC<TransactionLinkProps> = ({
  txHash,
  network = 'sepolia',
  className = "",
  showCopyButton = true
}) => {
  const [copied, setCopied] = useState(false);
  
  const starkscanUrl = getStarkscanUrl(network);
  const fullUrl = `${starkscanUrl}/tx/${txHash}`;
  const shortHash = `${txHash.slice(0, 8)}...${txHash.slice(-6)}`;
  
  const copyToClipboard = async () => {
    try {
      await navigator.clipboard.writeText(txHash);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (error) {
      console.error('Failed to copy to clipboard:', error);
    }
  };

  return (
    <div className={`inline-flex items-center gap-2 bg-success/10 border border-success/30 rounded-lg px-3 py-2 ${className}`}>
      <div className="flex items-center gap-2">
        <CheckCircle className="h-4 w-4 text-success" />
        <a
          href={fullUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="text-success hover:text-success/80 font-medium text-sm flex items-center gap-1 hover:underline"
        >
          <span>{shortHash}</span>
          <ExternalLink className="h-3 w-3" />
        </a>
      </div>
      
      {showCopyButton && (
        <button
          onClick={copyToClipboard}
          className="text-success hover:text-success/80 p-1 rounded transition-colors"
          title="Copy transaction hash"
        >
          {copied ? (
            <CheckCircle className="h-3 w-3" />
          ) : (
            <Copy className="h-3 w-3" />
          )}
        </button>
      )}
    </div>
  );
};