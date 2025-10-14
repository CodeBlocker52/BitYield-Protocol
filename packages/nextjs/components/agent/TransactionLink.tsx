// components/agent/TransactionLink.tsx
import React from "react";
import { ExternalLink, Copy, CheckCircle } from "lucide-react";
import { useState } from "react";
import { getHashScanUrl } from "../../utils/tokenConfig";

interface TransactionLinkProps {
  txHash: string;
  network?: 'mainnet' | 'testnet' | 'previewnet';
  className?: string;
  showCopyButton?: boolean;
}

export const TransactionLink: React.FC<TransactionLinkProps> = ({
  txHash,
  network = 'testnet',
  className = "",
  showCopyButton = true
}) => {
  const [copied, setCopied] = useState(false);
  
  const hashscanUrl = getHashScanUrl(network);
  const fullUrl = `${hashscanUrl}/transaction/${txHash}`;
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
    <div className={`inline-flex items-center space-x-2 bg-green-50 border border-green-200 rounded-lg px-3 py-2 ${className}`}>
      <div className="flex items-center space-x-2">
        <CheckCircle className="h-4 w-4 text-green-600" />
        <a
          href={fullUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="text-green-700 hover:text-green-800 font-medium text-sm flex items-center space-x-1 hover:underline"
        >
          <span>{shortHash}</span>
          <ExternalLink className="h-3 w-3" />
        </a>
      </div>
      
      {showCopyButton && (
        <button
          onClick={copyToClipboard}
          className="text-green-600 hover:text-green-800 p-1 rounded transition-colors"
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