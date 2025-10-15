"use client";

import React, { useState } from "react";
import { useAgent } from "~~/hooks/useAgent";
import { ChatArea } from "~~/components/chat/ChatArea";
import WalletConnectButton from "~~/components/wallet/WalletConnectButton";
import Image from "next/image";
import { useAccount } from "@starknet-react/core";

export default function YieldPage() {
  const agent = useAgent();
  const { isConnected } = useAccount();
  const [inputMessage, setInputMessage] = useState("");

  const handleSuggestionClick = async (action: string) => {
    // Map actions to messages
    const actionMessages: Record<string, string> = {
      checkBalance: "Check my vault balance and earnings",
      deposit: "I want to deposit WBTC",
      withdraw: "I want to withdraw from the vault",
      apy: "Show me current APY rates",
      analyzePortfolio: "Analyze my portfolio and suggest optimizations",
    };

    const message = actionMessages[action] || action;
    await agent.sendMessage(message);
  };

  const handleSendMessage = async () => {
    if (!inputMessage.trim()) return;
    await agent.sendMessage(inputMessage);
    setInputMessage("");
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-950 via-purple-950 to-slate-950 text-white flex flex-col">
      {/* Header */}
      <header className="border-b border-slate-800 bg-slate-950/50 backdrop-blur-lg">
        <div className="max-w-6xl mx-auto px-6 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <Image
                src="/BitYieldLogo.png"
                alt="BitYield Logo"
                width={40}
                height={40}
                className="rounded-xl"
              />
              <div>
                <h1 className="text-2xl font-bold bg-gradient-to-r from-orange-400 to-purple-400 bg-clip-text text-transparent">
                  BitYield AI Agent
                </h1>
                <div className="flex items-center gap-2 mt-1">
                  <div
                    className={`w-2 h-2 rounded-full ${agent.status.isConnected ? "bg-green-500 animate-pulse" : "bg-red-500"}`}
                  />
                  <span className="text-sm text-slate-400">
                    {agent.status.isConnected ? "Connected" : "Connecting..."}
                  </span>
                </div>
              </div>
            </div>

            {/* Stats & Wallet */}
            <div className="flex items-center gap-6">
              <div className="hidden md:flex items-center gap-6">
                <div className="text-center">
                  <p className="text-2xl font-bold text-purple-400">18.5%</p>
                  <p className="text-xs text-slate-500">Current APY</p>
                </div>
                <div className="text-center">
                  <p className="text-2xl font-bold text-orange-400">$12.4M</p>
                  <p className="text-xs text-slate-500">TVL</p>
                </div>
              </div>

              <WalletConnectButton />
            </div>
          </div>
        </div>
      </header>

      {/* Chat Area */}
      <ChatArea
        messages={agent.messages}
        inputMessage={inputMessage}
        setInputMessage={setInputMessage}
        onSendMessage={handleSendMessage}
        isTyping={agent.status.isProcessing}
        onSuggestionClick={handleSuggestionClick}
        agentStatus={agent.status}
        walletConnected={isConnected}
      />
    </div>
  );
}