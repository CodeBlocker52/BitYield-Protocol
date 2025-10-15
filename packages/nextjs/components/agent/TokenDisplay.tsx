import React from "react";
import { getTokenInfo } from "../../utils/tokenConfig";
import Image from "next/image";

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
  const [imageError, setImageError] = React.useState(false);
  
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
    <span className={`inline-flex items-center gap-1.5 ${className}`}>
      {!imageError ? (
        <Image
          src={tokenInfo.icon}
          alt={tokenInfo.name}
          width={size === 'sm' ? 16 : size === 'md' ? 20 : 24}
          height={size === 'sm' ? 16 : size === 'md' ? 20 : 24}
          className={`${sizeClasses[size]} rounded-full flex-shrink-0`}
          onError={() => setImageError(true)}
        />
      ) : (
        <div 
          className={`${sizeClasses[size]} rounded-full flex items-center justify-center text-white text-xs font-bold`}
          style={{ backgroundColor: tokenInfo.color }}
        >
          {symbol.charAt(0)}
        </div>
      )}
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