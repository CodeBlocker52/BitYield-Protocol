"use client";

import React, { useState, useEffect } from "react";
import {
  Send,
  Bot,
  User,
  Loader2,
  TrendingUp,
  Shield,
  Zap,
  ChevronRight,
  AlertCircle,
} from "lucide-react";

// ============================================
// TYPES & INTERFACES
// ============================================

interface ChatMessage {
  id: string;
  type: "user" | "bot" | "system";
  content: string;
  timestamp: Date;
  suggestions?: Suggestion[];
}

interface Suggestion {
  text: string;
  action: string;
  type: "info" | "success" | "warning";
}

interface AgentStatus {
  isConnected: boolean;
  isHealthy: boolean;
  isProcessing: boolean;
  error: string | null;
}

// ============================================
// MOCK AGENT SERVICE (Replace with your actual LangGraph agent)
// ============================================

const mockAgentService = {
  isConnected: false,

  async connect() {
    return new Promise((resolve) => {
      setTimeout(() => {
        this.isConnected = true;
        resolve(true);
      }, 1000);
    });
  },

  async sendMessage(
    message: string
  ): Promise<{ message: string; timestamp: string }> {
    return new Promise((resolve) => {
      setTimeout(() => {
        const responses: Record<string, string> = {
          "check balance":
            "💰 **Your BitYield Portfolio**\n\n• **Deposited**: 0.5 WBTC ($45,230)\n• **Vault Shares**: 502.45 byWBTC\n• **Current APY**: 18.5%\n• **Earnings (30d)**: 0.0076 WBTC ($689)\n\n🎯 **Strategy Allocation**:\n• Vesu Lending: 60% (0.3 WBTC)\n• Troves Staking: 40% (0.2 WBTC)",
          deposit:
            "📥 **Deposit to BitYield Vault**\n\nTo deposit WBTC:\n1. Ensure you have WBTC in your wallet\n2. Approve WBTC spending\n3. Enter amount and confirm\n\nCurrent vault stats:\n• TVL: $12.4M\n• Your share: 0.04%\n• Expected APY: 18.5%\n\nHow much would you like to deposit?",
          withdraw:
            "📤 **Withdraw from Vault**\n\nYour balance:\n• 502.45 byWBTC shares\n• ≈ 0.502 WBTC ($45,456)\n\n⚠️ **Note**: Withdrawals may take up to 24h if funds are in active strategies.\n\nHow much would you like to withdraw?",
          apy: "📊 **Current Yield Rates**\n\n**BitYield Vault**: 18.5% APY\n• Vesu WBTC Lending: 12.3%\n• Troves WBTC Staking: 26.8%\n• Weighted Average: 18.5%\n\n**Market Comparison**:\n• Aave WBTC: 3.2%\n• Compound WBTC: 2.8%\n• Curve tricrypto: 15.4%\n\n🚀 BitYield is currently **5.7x better** than traditional lending!",
        };

        const lowerMessage = message.toLowerCase();
        let response =
          responses[lowerMessage] ||
          `I understand you said: "${message}"\n\n🤖 I can help you with:\n• Check your balance and earnings\n• Deposit WBTC to earn yields\n• Withdraw your funds\n• View current APY rates\n• Analyze yield strategies\n\nWhat would you like to do?`;

        resolve({
          message: response,
          timestamp: new Date().toISOString(),
        });
      }, 1500);
    });
  },
};

// ============================================
// CHAT MESSAGE COMPONENT
// ============================================

const ChatMessageComponent: React.FC<{
  message: ChatMessage;
  onSuggestionClick: (action: string) => void;
}> = ({ message, onSuggestionClick }) => {
  const isUser = message.type === "user";
  const isSystem = message.type === "system";

  if (isSystem) {
    return (
      <div className="flex justify-center my-4">
        <div className="flex items-center gap-2 px-4 py-2 bg-purple-500/10 border border-purple-500/30 rounded-full text-sm text-purple-300">
          <AlertCircle className="w-4 h-4" />
          <span>{message.content}</span>
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
              <img
                src="/BitYieldLogo.png"
                alt="BitYield Logo"
                className="rounded-full"
                width={40}
                height={40}
              />
            )}
          </div>

          {/* Message Content */}
          <div>
            <div
              className={`p-4 rounded-2xl ${
                isUser
                  ? "bg-gradient-to-r from-orange-500/20 to-purple-600/20 border border-purple-500/30"
                  : "bg-slate-900/50 border border-slate-800"
              }`}
            >
              <div className="text-sm leading-relaxed whitespace-pre-line text-white">
                {message.content}
              </div>
            </div>

            {/* Suggestions */}
            {message.suggestions && message.suggestions.length > 0 && (
              <div className="flex flex-wrap gap-2 mt-3">
                {message.suggestions.map((suggestion, idx) => (
                  <button
                    key={idx}
                    onClick={() => onSuggestionClick(suggestion.action)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-all hover:scale-105 ${
                      suggestion.type === "success"
                        ? "bg-green-500/20 border border-green-500/50 text-green-300 hover:bg-green-500/30"
                        : suggestion.type === "warning"
                          ? "bg-orange-500/20 border border-orange-500/50 text-orange-300 hover:bg-orange-500/30"
                          : "bg-purple-500/20 border border-purple-500/50 text-purple-300 hover:bg-purple-500/30"
                    }`}
                  >
                    {suggestion.text}
                  </button>
                ))}
              </div>
            )}

            {/* Timestamp */}
            <div
              className={`text-xs text-slate-500 mt-2 ${isUser ? "text-right" : ""}`}
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

// ============================================
// TYPING INDICATOR
// ============================================

const TypingIndicator: React.FC<{ isVisible: boolean }> = ({ isVisible }) => {
  if (!isVisible) return null;

  return (
    <div className="flex items-start gap-3 mb-6">
      <div className="w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 bg-gradient-to-br from-orange-500 to-purple-600">
        <img
          src="/BitYieldLogo.png"
          alt="BitYield Logo"
          className="rounded-full"
          width={40}
          height={40}
        />
      </div>
      <div className="bg-slate-900/50 border border-slate-800 p-4 rounded-2xl">
        <div className="flex items-center gap-2">
          <div className="flex gap-1">
            <div
              className="w-2 h-2 bg-purple-400 rounded-full animate-bounce"
              style={{ animationDelay: "0ms" }}
            />
            <div
              className="w-2 h-2 bg-purple-400 rounded-full animate-bounce"
              style={{ animationDelay: "150ms" }}
            />
            <div
              className="w-2 h-2 bg-purple-400 rounded-full animate-bounce"
              style={{ animationDelay: "300ms" }}
            />
          </div>
          <span className="text-sm text-slate-400">AI is thinking...</span>
        </div>
      </div>
    </div>
  );
};

// ============================================
// MAIN COMPONENT
// ============================================

export default function BitYieldChatAgent() {
  const [messages, setMessages] = useState<ChatMessage[]>([
    {
      id: "1",
      type: "bot",
      content:
        "Welcome to **BitYield AI**! 🤖\n\nI'm your intelligent DeFi advisor powered by LangGraph. I can help you:\n\n• 📊 Check your vault balance and earnings\n• 💰 Deposit WBTC to earn yields\n• 📤 Withdraw your funds\n• 📈 Analyze yield strategies\n• ⚡ Execute smart rebalancing\n\nWhat would you like to do today?",
      timestamp: new Date(),
      suggestions: [
        { text: "💰 Check Balance", action: "check balance", type: "info" },
        { text: "📥 Deposit WBTC", action: "deposit", type: "success" },
        { text: "📊 View APY", action: "apy", type: "info" },
        { text: "📤 Withdraw", action: "withdraw", type: "warning" },
      ],
    },
  ]);

  const [inputMessage, setInputMessage] = useState("");
  const [isTyping, setIsTyping] = useState(false);
  const [agentStatus, setAgentStatus] = useState<AgentStatus>({
    isConnected: false,
    isHealthy: false,
    isProcessing: false,
    error: null,
  });

  // Connect to agent on mount
  useEffect(() => {
    connectAgent();
  }, []);

  const connectAgent = async () => {
    try {
      await mockAgentService.connect();
      setAgentStatus({
        isConnected: true,
        isHealthy: true,
        isProcessing: false,
        error: null,
      });

      addSystemMessage("✅ Connected to BitYield AI Agent");
    } catch (error) {
      setAgentStatus({
        isConnected: false,
        isHealthy: false,
        isProcessing: false,
        error: "Failed to connect to agent",
      });
    }
  };

  const addSystemMessage = (content: string) => {
    const systemMessage: ChatMessage = {
      id: `system-${Date.now()}`,
      type: "system",
      content,
      timestamp: new Date(),
    };
    setMessages((prev) => [...prev, systemMessage]);
  };

  const handleSendMessage = async () => {
    if (!inputMessage.trim()) return;

    const userMessage: ChatMessage = {
      id: `user-${Date.now()}`,
      type: "user",
      content: inputMessage.trim(),
      timestamp: new Date(),
    };

    setMessages((prev) => [...prev, userMessage]);
    setInputMessage("");
    setIsTyping(true);

    try {
      const response = await mockAgentService.sendMessage(userMessage.content);

      const botMessage: ChatMessage = {
        id: `bot-${Date.now()}`,
        type: "bot",
        content: response.message,
        timestamp: new Date(response.timestamp),
      };

      setMessages((prev) => [...prev, botMessage]);
    } catch (error) {
      addSystemMessage("❌ Failed to get response from agent");
    } finally {
      setIsTyping(false);
    }
  };

  const handleSuggestionClick = async (action: string) => {
    // Simulate sending the suggestion as a message
    await new Promise((resolve) => {
      setInputMessage(action);
      setTimeout(resolve, 100);
    });
    await handleSendMessage();
  };

  const quickActions = [
    { label: "Best yields", message: "Show me the best yield opportunities" },
    { label: "Risk analysis", message: "Analyze risks in my portfolio" },
    { label: "Auto-compound", message: "Set up auto-compounding" },
    {
      label: "BTC opportunities",
      message: "Show Bitcoin native opportunities",
    },
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-950 via-purple-950 to-slate-950 text-white">
      <div className="max-w-6xl mx-auto h-screen flex flex-col">
        {/* Header */}
        <div className="border-b border-slate-800 bg-slate-950/50 backdrop-blur-lg">
          <div className="px-6 py-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-4">
                <img
                  src="/BitYieldLogo.png"
                  alt="BitYield Logo"
                  className="rounded-xl"
                  width={40}
                  height={40}
                />
                <div>
                  <h1 className="text-2xl font-bold bg-gradient-to-r from-orange-400 to-purple-400 bg-clip-text text-transparent">
                    BitYield AI Agent
                  </h1>
                  <div className="flex items-center gap-2 mt-1">
                    <div
                      className={`w-2 h-2 rounded-full ${agentStatus.isConnected ? "bg-green-500 animate-pulse" : "bg-red-500"}`}
                    />
                    <span className="text-sm text-slate-400">
                      {agentStatus.isConnected ? "Connected" : "Disconnected"}
                    </span>
                  </div>
                </div>
              </div>

              {/* Stats */}
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
            </div>
          </div>
        </div>

        {/* Chat Messages */}
        <div className="flex-1 overflow-y-auto px-6 py-6">
          {messages.map((message) => (
            <ChatMessageComponent
              key={message.id}
              message={message}
              onSuggestionClick={handleSuggestionClick}
            />
          ))}
          <TypingIndicator isVisible={isTyping} />
        </div>

        {/* Input Area */}
        <div className="border-t border-slate-800 bg-slate-950/50 backdrop-blur-lg px-6 py-4">
          {/* Quick Actions */}
          <div className="flex flex-wrap gap-2 mb-4">
            {quickActions.map((action, idx) => (
              <button
                key={idx}
                onClick={() => setInputMessage(action.message)}
                className="px-3 py-1.5 bg-slate-800/50 border border-slate-700 rounded-lg text-xs text-slate-300 hover:bg-slate-800 hover:border-purple-500/50 transition-all"
              >
                &quot;{action.label}&quot;
              </button>
            ))}
          </div>

          {/* Input */}
          <div className="flex items-center gap-3">
            <input
              type="text"
              value={inputMessage}
              onChange={(e) => setInputMessage(e.target.value)}
              onKeyPress={(e) =>
                e.key === "Enter" && !e.shiftKey && handleSendMessage()
              }
              placeholder="Ask about yield strategies, risk analysis, portfolio optimization..."
              className="flex-1 px-4 py-3 bg-slate-900/50 border border-slate-800 rounded-xl text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-purple-500/50 focus:border-transparent"
              disabled={isTyping || !agentStatus.isConnected}
            />
            <button
              onClick={handleSendMessage}
              disabled={
                !inputMessage.trim() || isTyping || !agentStatus.isConnected
              }
              className="px-6 py-3 bg-gradient-to-r from-orange-500 to-purple-600 rounded-xl font-semibold hover:shadow-lg hover:shadow-purple-500/50 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
            >
              {isTyping ? (
                <Loader2 className="w-5 h-5 animate-spin" />
              ) : (
                <Send className="w-5 h-5" />
              )}
            </button>
          </div>

          {/* Agent Error */}
          {agentStatus.error && (
            <div className="mt-3 px-4 py-2 bg-red-500/10 border border-red-500/30 rounded-lg">
              <p className="text-sm text-red-400">⚠️ {agentStatus.error}</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
