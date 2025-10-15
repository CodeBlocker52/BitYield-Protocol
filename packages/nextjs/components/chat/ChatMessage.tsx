// components/chat/ChatMessage.tsx
// Enhanced with TokenDisplay and TransactionLink (applied also to message.content)

import React from "react";
import { User, AlertCircle } from "lucide-react";
import Image from "next/image";
import { TokenDisplay } from "../agent/TokenDisplay";
import { TransactionLink } from "../agent/TransactionLink";
import { StarknetNetwork } from "../../utils/tokenConfig";

interface Message {
  id: string;
  type: "user" | "bot" | "system" | "event";
  content: string;
  timestamp: Date;
  metadata?: {
    txHash?: string;
    network?: StarknetNetwork;
    tokens?: Array<{ symbol: string; amount: string }>;
  };
  suggestions?: Array<{
    text: string;
    action: string;
    type: "info" | "success" | "warning";
  }>;
}

interface ChatMessageProps {
  message: Message;
  onSuggestionClick: (action: string) => void;
}

// Enhanced message formatting with token and transaction support
const formatMessage = (
  content: string,
  metadata?: Message["metadata"]
): React.ReactNode => {
  const lines = content.split("\n");
  const txPattern = /(0x[a-fA-F0-9]{6,66})/g;
  const tokenPattern =
    /\b(BTC|WBTC|STRK|USDC|ETH)\s*:\s*(\d+\.?\d*)|\b(\d+\.?\d*)\s+(BTC|WBTC|STRK|USDC|ETH)\b/gi;
  const boldPattern = /\*\*(.*?)\*\*/g;

  return lines.map((line, index) => {
    if (!line.trim()) return <br key={index} />;

    const segments: React.ReactNode[] = [];
    let last = 0;
    let m;

    txPattern.lastIndex = 0;
    while ((m = txPattern.exec(line)) !== null) {
      if (m.index > last) segments.push(line.slice(last, m.index));
      segments.push(
        <TransactionLink
          key={`tx-${index}-${m.index}`}
          txHash={m[1]}
          network={metadata?.network || "sepolia"}
          className="inline-flex mx-1"
        />
      );
      last = m.index + m[0].length;
    }
    if (last < line.length) segments.push(line.slice(last));

    const rendered = segments.map((seg, i) => {
      if (typeof seg !== "string") return <span key={`seg-${i}`}>{seg}</span>;

      const tokenParts: React.ReactNode[] = [];
      let li = 0;
      tokenPattern.lastIndex = 0;
      let t;

      while ((t = tokenPattern.exec(seg)) !== null) {
        if (t.index > li) tokenParts.push(seg.slice(li, t.index));

        // handle both match patterns: `BTC: 10.5234` or `10.5234 BTC`
        const symbol = t[1] || t[4];
        const amount = t[2] || t[3];

        tokenParts.push(
          <TokenDisplay
            key={`token-${index}-${i}-${t.index}`}
            symbol={symbol}
            amount={amount}
            size="sm"
            className="mx-1"
          />
        );
        li = t.index + t[0].length;
      }

      if (li < seg.length) tokenParts.push(seg.slice(li));

      // Bold formatting (only if no tokens)
      if (tokenParts.length === 1 && typeof tokenParts[0] === "string") {
        const boldParts: React.ReactNode[] = [];
        let bi = 0;
        let b;
        boldPattern.lastIndex = 0;
        while ((b = boldPattern.exec(seg)) !== null) {
          if (b.index > bi) boldParts.push(seg.slice(bi, b.index));
          boldParts.push(
            <strong
              key={`bold-${index}-${i}-${b.index}`}
              className="font-bold text-orange-400"
            >
              {b[1]}
            </strong>
          );
          bi = b.index + b[0].length;
        }
        if (bi < seg.length) boldParts.push(seg.slice(bi));
        return <span key={`seg-${i}`}>{boldParts.length ? boldParts : seg}</span>;
      }

      return <span key={`seg-${i}`}>{tokenParts}</span>;
    });

    // bullet points support
    if (line.trim().startsWith("•") || line.trim().startsWith("-")) {
      return (
        <div key={index} className="flex gap-2 ml-2">
          <span className="text-purple-400">•</span>
          <span className="flex">{rendered}</span>
        </div>
      );
    }

    return (
      <div key={index} className="flex items-center">
        {rendered}
      </div>
    );
  });
};


export const ChatMessage: React.FC<ChatMessageProps> = ({
  message,
  onSuggestionClick,
}) => {
  const isUser = message.type === "user";
  const isSystem = message.type === "system";
  const isEvent = message.type === "event";

  if (isSystem || isEvent) {
    return (
      <div className="flex justify-center my-4">
        <div className="flex items-center gap-2 px-4 py-2 bg-purple-500/10 border border-purple-500/30 rounded-full text-sm text-purple-300">
          <AlertCircle className="w-4 h-4" />
          <span className="flex">{message.content}</span>
        </div>
      </div>
    );
  }

  return (
    <div className={`flex ${isUser ? "justify-end" : "justify-start"} mb-6`}>
      <div className={`max-w-[85%] ${isUser ? "order-1" : ""}`}>
        <div
          className={`flex items-start gap-3 ${isUser ? "flex-row-reverse" : ""}`}
        >
          {/* Avatar */}
          <div
            className={`w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 ${
              isUser
                ? "bg-slate-800 border-2 border-slate-700"
                : "bg-gradient-to-br from-orange-500 to-purple-600"
            }`}
          >
            {isUser ? (
              <User className="w-5 h-5 text-slate-300" />
            ) : (
              <Image
                src="/BitYieldLogo.png"
                alt="BitYield Logo"
                className="rounded-xl"
                width={40}
                height={40}
              />
            )}
          </div>

          {/* Message Content */}
          <div>
            <div
              className={`p-4 rounded-2xl shadow-lg ${
                isUser
                  ? "bg-gradient-to-r from-orange-500/20 to-purple-600/20 border border-purple-500/30"
                  : "bg-slate-900/50 border border-slate-800"
              }`}
            >
              <div className="text-sm leading-relaxed text-white">
                {formatMessage(message.content, message.metadata)}
              </div>

              {/* Display tokens from metadata */}
              {message.metadata?.tokens?.length ? (
                <div className="mt-3 flex flex-wrap gap-2">
                  {message.metadata.tokens.map((token, idx) => (
                    <TokenDisplay
                      key={idx}
                      symbol={token.symbol}
                      amount={token.amount}
                      size="md"
                      className="bg-slate-800/50 px-2 py-1 rounded-lg"
                    />
                  ))}
                </div>
              ) : null}
            </div>

            {/* Suggestions */}
            {message.suggestions?.length ? (
              <div className="flex flex-wrap gap-2 mt-3">
                {message.suggestions.map((suggestion, idx) => (
                  <button
                    key={idx}
                    onClick={() => onSuggestionClick(suggestion.action)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all hover:scale-105 ${
                      suggestion.type === "success"
                        ? "bg-success/20 border border-success/50 text-success hover:bg-success/30"
                        : suggestion.type === "warning"
                        ? "bg-warning/20 border border-warning/50 text-warning hover:bg-warning/30"
                        : "bg-info/20 border border-info/50 text-info hover:bg-info/30"
                    }`}
                  >
                    {suggestion.text}
                  </button>
                ))}
              </div>
            ) : null}

            {/* Timestamp */}
            <div
              className={`text-xs text-slate-500 mt-2 ${
                isUser ? "text-right" : ""
              }`}
            >
              {message.timestamp.toLocaleTimeString([], {
                hour: "2-digit",
                minute: "2-digit",
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};