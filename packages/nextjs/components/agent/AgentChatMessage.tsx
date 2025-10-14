// components/agent/AgentChatMessage.tsx
import React from "react";
import { Bot, User, AlertCircle, Clock, CheckCircle, XCircle } from "lucide-react";
import { TransactionLink } from "./TransactionLink";
import { TokenDisplay } from "./TokenDisplay";
import { ChatMessageData } from "../chat/ChatMessage";

interface AgentChatMessageProps {
  message: ChatMessageData;
  network?: 'mainnet' | 'testnet' | 'previewnet';
}

const getStatusIcon = (status?: string) => {
  switch (status) {
    case 'pending':
      return <Clock className="h-3 w-3 text-amber-400 animate-pulse" />;
    case 'delivered':
      return <CheckCircle className="h-3 w-3 text-green-400" />;
    case 'error':
      return <XCircle className="h-3 w-3 text-red-400" />;
    default:
      return null;
  }
};

// Enhanced function to detect and parse transaction hashes
const detectTransactionHashes = (content: string): string[] => {
  // Hedera transaction hash patterns
  const patterns = [
    // Standard Hedera transaction ID format: 0.0.xxxxx@timestamp.nanoseconds
    /0\.0\.\d+@\d+\.\d+/g,
    // Alternative formats sometimes used
    /\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b/g,
    // Another common format
    /\b[0-9a-fA-F]{64}\b/g,
    /0x[0-9a-fA-F]{64}\b/g
  ];
  
  const hashes: string[] = [];
  patterns.forEach(pattern => {
    const matches = content.match(pattern);
    if (matches) {
      hashes.push(...matches);
    }
  });
  
  return [...new Set(hashes)]; // Remove duplicates
};

// Enhanced function to detect token mentions and replace with TokenDisplay
const enhanceTokenDisplay = (content: string): React.ReactNode[] => {
  // Token patterns with amounts
  const tokenWithAmountPattern = /([\d,]+(?:\.\d+)?)\s+(HBAR|USDC|SAUCE|WHBAR|BTC)/gi;
  // Token patterns without amounts
  const tokenOnlyPattern = /\b(HBAR|USDC|SAUCE|WHBAR)\b/gi;
  
  const parts: React.ReactNode[] = [];
  let lastIndex = 0;
  let partIndex = 0;
  
  // First, handle tokens with amounts
  let match;
  const processedRanges: Array<[number, number]> = [];
  
  // Reset regex
  tokenWithAmountPattern.lastIndex = 0;
  
  while ((match = tokenWithAmountPattern.exec(content)) !== null) {
    const [fullMatch, amount, symbol] = match;
    const start = match.index;
    const end = start + fullMatch.length;
    
    // Add text before the match
    if (start > lastIndex) {
      const textBefore = content.slice(lastIndex, start);
      if (textBefore) {
        parts.push(
          <span key={`text-${partIndex++}`}>
            {textBefore}
          </span>
        );
      }
    }
    
    // Add TokenDisplay component
    parts.push(
      <TokenDisplay
        key={`token-${partIndex++}`}
        symbol={symbol}
        amount={amount}
        showAmount={true}
        className="mx-1"
      />
    );
    
    processedRanges.push([start, end]);
    lastIndex = end;
  }
  
  // Then handle remaining token-only mentions
  tokenOnlyPattern.lastIndex = 0;
  const remainingContent = content.slice(lastIndex);
  let remainingLastIndex = 0;
  
  while ((match = tokenOnlyPattern.exec(remainingContent)) !== null) {
    const [fullMatch, symbol] = match;
    const absoluteStart = lastIndex + match.index;
    const absoluteEnd = absoluteStart + fullMatch.length;
    
    // Check if this range was already processed
    const isAlreadyProcessed = processedRanges.some(([start, end]) => 
      absoluteStart >= start && absoluteEnd <= end
    );
    
    if (isAlreadyProcessed) continue;
    
    // Add text before the match
    const localStart = match.index;
    if (localStart > remainingLastIndex) {
      const textBefore = remainingContent.slice(remainingLastIndex, localStart);
      if (textBefore) {
        parts.push(
          <span key={`text-${partIndex++}`}>
            {textBefore}
          </span>
        );
      }
    }
    
    // Add TokenDisplay component
    parts.push(
      <TokenDisplay
        key={`token-${partIndex++}`}
        symbol={symbol}
        showAmount={false}
        className="mx-1"
      />
    );
    
    remainingLastIndex = localStart + fullMatch.length;
  }
  
  // Add remaining text
  if (remainingLastIndex < remainingContent.length) {
    const finalText = remainingContent.slice(remainingLastIndex);
    if (finalText) {
      parts.push(
        <span key={`text-${partIndex++}`}>
          {finalText}
        </span>
      );
    }
  } else if (parts.length === 0) {
    // If no tokens were found, return the original content
    return [<span key="original">{content}</span>];
  }
  
  return parts;
};

const formatAgentResponse = (content: string, network: 'mainnet' | 'testnet' | 'previewnet' = 'testnet'): React.ReactNode => {
  // Detect transaction hashesAlertCircle
  console.log('content', content)
  const txHashes = detectTransactionHashes(content);
  
  // Split content by lines for processing
  const lines = content.split('\n');
  
  return (
    <div className="space-y-2">
      {lines.map((line, lineIndex) => {
        if (!line.trim()) {
          return <br key={`br-${lineIndex}`} />;
        }
        
        // Check if line contains transaction hash
        const lineHashes = txHashes.filter(hash => line.includes(hash));
        
        if (lineHashes.length > 0) {
          // Process line with transaction hashes
          const processedLine = line;
          const lineComponents: React.ReactNode[] = [];
          let lastIndex = 0;
          
          lineHashes.forEach((hash, hashIndex) => {
            const hashIndex_start = processedLine.indexOf(hash, lastIndex);
            if (hashIndex_start !== -1) {
              // Add text before hash
              const beforeText = processedLine.slice(lastIndex, hashIndex_start);
              if (beforeText) {
                const enhancedBefore = enhanceTokenDisplay(beforeText);
                lineComponents.push(
                  <span key={`before-${lineIndex}-${hashIndex}`}>
                    {enhancedBefore}
                  </span>
                );
              }
              
              // Add transaction link
              lineComponents.push(
                <TransactionLink
                  key={`tx-${lineIndex}-${hashIndex}`}
                  txHash={hash}
                  network={network}
                  className="mx-1"
                />
              );
              
              lastIndex = hashIndex_start + hash.length;
            }
          });
          
          // Add remaining text
          if (lastIndex < processedLine.length) {
            const remainingText = processedLine.slice(lastIndex);
            if (remainingText) {
              const enhancedRemaining = enhanceTokenDisplay(remainingText);
              lineComponents.push(
                <span key={`after-${lineIndex}`}>
                  {enhancedRemaining}
                </span>
              );
            }
          }
          
          return (
            <div key={`line-${lineIndex}`} className="leading-relaxed">
              {lineComponents}
            </div>
          );
        } else {
          // Process line for token display only
          const enhancedLine = enhanceTokenDisplay(line);
          return (
            <div key={`line-${lineIndex}`} className="leading-relaxed">
              {enhancedLine}
            </div>
          );
        }
      })}
    </div>
  );
};

export const AgentChatMessage: React.FC<AgentChatMessageProps> = ({ 
  message, 
  network = 'testnet' 
}) => {
  const isUser = message.type === 'user';
  const isSystem = message.type === 'system';
  const isAgent = message.type === 'bot';

  if (isSystem) {
    return (
      <div className="flex justify-center my-4">
        <div className="flex items-center space-x-2 px-3 py-2 bg-muted/30 rounded-full text-sm text-muted-foreground">
          <AlertCircle className="h-4 w-4" />
          <span>{message.message}</span>
        </div>
      </div>
    );
  }

  return (
    <div className={`flex ${isUser ? 'justify-end' : 'justify-start'} mb-6`}>
      <div className={`max-w-[85%] ${isUser ? 'order-1' : ''}`}>
        <div className={`flex items-start space-x-3 ${
          isUser ? 'flex-row-reverse space-x-reverse' : ''
        }`}>
          {/* Avatar */}
          <div className={`w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 ${
            isUser 
              ? 'bg-muted/30 border-2 border-muted' 
              : 'bg-gradient-to-br from-primary to-purple-500'
          }`}>
            {isUser ? (
              <User className="h-5 w-5 text-muted-foreground" />
            ) : (
              <img
                src="/yieldCraftLogo.png"
                alt="YieldCraft Logo"
                width={70}
                height={70}
              />
            )}
          </div>

          {/* Message Content */}
          <div className={`${isUser ? 'text-right' : ''}`}>
            <div className={`p-4 rounded-2xl shadow-md ${
              isUser 
                ? 'bg-primary text-primary-foreground border border-primary/30'
                : 'glass border border-border/30'
            }`}>
              <div className="text-sm leading-relaxed">
                {isAgent ? (
                  formatAgentResponse(message.message, network)
                ) : (
                  <span className="whitespace-pre-line">{message.message}</span>
                )}
              </div>
            </div>

            {/* Timestamp and Status */}
            <div className={`flex items-center space-x-2 mt-2 text-xs text-muted-foreground ${
              isUser ? 'justify-end' : 'justify-start'
            }`}>
              <span>{message.timestamp}</span>
              {/* {message.status && getStatusIcon(message.status)} */}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};