// components/agent/TokenDisplay.tsx
import React from "react";
import { getTokenInfo } from "../../utils/tokenConfig";

interface TokenDisplayProps {
  symbol: string;
  amount?: string;
  showAmount?: boolean;
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}

export const TokenDisplay: React.FC<TokenDisplayProps> = ({
  symbol,
  amount,
  showAmount = true,
  size = 'md',
  className = ""
}) => {
  const tokenInfo = getTokenInfo(symbol);
  
  const sizeClasses = {
    sm: 'h-4 w-4',
    md: 'h-5 w-5',
    lg: 'h-6 w-6'
  };
  
  const textSizeClasses = {
    sm: 'text-sm',
    md: 'text-base',
    lg: 'text-lg'
  };

  return (
    <span className={`inline-flex items-center space-x-1 ${className}`}>
      <img
        src={tokenInfo.icon}
        alt={tokenInfo.name}
        className={`${sizeClasses[size]} rounded-full flex-shrink-0`}
        onError={(e) => {
          // Fallback to a colored circle with symbol if image fails to load
          const target = e.target as HTMLImageElement;
          target.style.display = 'none';
          const fallback = target.nextElementSibling as HTMLElement;
          if (fallback) fallback.style.display = 'flex';
        }}
      />
      <div 
        className={`${sizeClasses[size]} rounded-full flex items-center justify-center text-white text-xs font-bold hidden`}
        style={{ backgroundColor: tokenInfo.color }}
      >
        {symbol.charAt(0)}
      </div>
      {showAmount && amount && (
        <span className={`font-medium ${textSizeClasses[size]}`}>
          {amount} {symbol}
        </span>
      )}
      {!showAmount && (
        <span className={`font-medium ${textSizeClasses[size]}`}>
          {symbol}
        </span>
      )}
    </span>
  );
};