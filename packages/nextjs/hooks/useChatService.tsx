// hooks/useEnhancedChatService.ts
import { useState, useCallback, useEffect } from "react";
import {
  ChatMessageData,
  ChatSuggestion,
} from "../components/chat/ChatMessage";
// import { useAppKitContext } from "@/context/AppKitContext";
// import { useWallet } from "./useHederaWallet";
import { useAgent, AgentMessage } from "./useAgent";

// Enhanced initial message with agent integration
const initialChatMessages: ChatMessageData[] = [
  {
    type: "bot",
    message:
      "Welcome to BitYield AI! I'm your intelligent DeFi advisor powered by Hedera's AI Agent Kit. I can help you discover yield opportunities, analyze risks, execute strategies, and manage your portfolio.\n\n🤖 **Agent Status**: Connecting to advanced DeFi capabilities...\n\nHow can I assist you today?",
    timestamp: "Just now",
    suggestions: [
      { text: "Check my balance", type: "info", action: "checkBalance" },
      { text: "Create limit order", type: "success", action: "createOrder" },
      { text: "Monitor orders", type: "warning", action: "monitorOrders" },
      { text: "Portfolio analysis", type: "info", action: "analyzePortfolio" },
    ],
  },
];

export const useChatService = () => {
  const [inputMessage, setInputMessage] = useState("");
  const [messages, setMessages] =
    useState<ChatMessageData[]>(initialChatMessages);
  const [isTyping, setIsTyping] = useState(false);

  // const { isInitialized } = useAppKitContext();
  // const wallet = useWallet();
  const isInitialized = false;
  const wallet = {
    isConnected: false,
    error: null,
    chainId: null,
    getShortAddress: () => "",
    getNetworkName: () => "Unknown",
    connectWallet: () => {},
  };
  const agent = useAgent();

  // Convert agent messages to chat format
  const convertAgentMessage = useCallback(
    (agentMsg: AgentMessage): ChatMessageData => {
      return {
        type:
          agentMsg.type === "agent"
            ? "bot"
            : agentMsg.type === "user"
              ? "user"
              : "bot",
        message: agentMsg.content,
        timestamp: agentMsg.timestamp.toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit",
        }),
      };
    },
    []
  );

  // Update messages when agent messages change
  useEffect(() => {
    if (agent.messages.length > 0) {
      const convertedMessages = agent.messages.map(convertAgentMessage);
      // Only update if different from current messages
      setMessages((prev) => {
        if (prev.length === convertedMessages.length + 1) return prev; // +1 for initial message
        return [initialChatMessages[0], ...convertedMessages];
      });
    }
  }, [agent.messages, convertAgentMessage]);

  // Update typing status based on agent processing
  useEffect(() => {
    setIsTyping(agent.status.isProcessing);
  }, [agent.status.isProcessing]);

  // Update initial message based on agent status
  useEffect(() => {
    const statusMessage = agent.status.error
      ? `❌ **Agent Error**: ${agent.status.error}`
      : agent.status.isConnected
        ? "✅ **Agent Ready**: Connected to BitYield AI with full DeFi capabilities"
        : "🔄 **Agent Status**: Connecting to advanced DeFi capabilities...";

    const updatedInitialMessage: ChatMessageData = {
      ...initialChatMessages[0],
      message: `Welcome to BitYield AI! I'm your intelligent DeFi advisor powered by Hedera's AI Agent Kit. I can help you discover yield opportunities, analyze risks, execute strategies, and manage your portfolio.\n\n${statusMessage}\n\nHow can I assist you today?`,
    };

    setMessages((prev) => [updatedInitialMessage, ...prev.slice(1)]);
  }, [agent.status]);

  // Get wallet info safely
  const getWalletInfo = useCallback(() => {
    if (!isInitialized) {
      return {
        isConnected: false,
        getShortAddress: () => "",
        getNetworkName: () => "Initializing...",
        connectWallet: () => console.warn("AppKit not initialized"),
      };
    }

    try {
      return wallet;
    } catch (error) {
      console.warn("Failed to load wallet hook:", error);
      return {
        isConnected: false,
        getShortAddress: () => "",
        getNetworkName: () => "Unknown",
        connectWallet: () => {},
      };
    }
  }, [isInitialized, wallet]);

  // Enhanced message handling with agent integration
  const handleSendMessage = useCallback(async () => {
    if (!inputMessage.trim()) return;

    const message = inputMessage.trim();
    setInputMessage("");

    // If agent is ready, use agent service
    if (agent.isReady) {
      await agent.sendMessage(message);
    } else {
      // Fallback to simulated responses when agent is not available
      const userMessage: ChatMessageData = {
        type: "user",
        message,
        timestamp: new Date().toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit",
        }),
      };

      setMessages((prev) => [...prev, userMessage]);
      setIsTyping(true);

      setTimeout(() => {
        const fallbackResponse: ChatMessageData = {
          type: "bot",
          message: `I'm currently connecting to the BitYield AI agent to process your request: "${message}"\n\n🔄 **Status**: ${agent.status.error || "Establishing connection..."}\n\nPlease wait while I connect to provide you with advanced DeFi capabilities including:\n• Real-time balance checking\n• AutoSwap limit orders\n• Portfolio monitoring\n• Transaction management`,
          timestamp: new Date().toLocaleTimeString([], {
            hour: "2-digit",
            minute: "2-digit",
          }),
          suggestions: [
            {
              text: "Retry connection",
              type: "info",
              action: "retryConnection",
            },
            { text: "Check status", type: "warning", action: "checkStatus" },
          ],
        };

        setMessages((prev) => [...prev, fallbackResponse]);
        setIsTyping(false);
      }, 1500);
    }
  }, [inputMessage, agent]);

  // Handle suggestion clicks with agent integration
  const handleSuggestionClick = useCallback(
    async (action: string) => {
      const walletInfo = getWalletInfo();

      // Agent-specific actions
      if (action === "retryConnection") {
        await agent.connect();
        return;
      }

      if (action === "checkStatus") {
        const statusMsg = `🔍 **System Status**\n\n• **Agent Connection**: ${agent.status.isConnected ? "Connected" : "Disconnected"}\n• **Agent Health**: ${agent.status.isHealthy ? "Healthy" : "Unhealthy"}\n• **Wallet**: ${walletInfo.isConnected ? "Connected" : "Not Connected"}\n• **Network**: ${walletInfo.getNetworkName()}\n\n${agent.status.error ? `**Error**: ${agent.status.error}` : "All systems operational"}`;

        const statusMessage: ChatMessageData = {
          type: "bot",
          message: statusMsg,
          timestamp: new Date().toLocaleTimeString([], {
            hour: "2-digit",
            minute: "2-digit",
          }),
        };

        setMessages((prev) => [...prev, statusMessage]);
        return;
      }

      // Agent-powered DeFi actions
      if (agent.isReady) {
        const actionMessages: Record<string, string> = {
          checkBalance: "Check my HBAR and token balances",
          createOrder: "I want to create a new AutoSwap limit order",
          monitorOrders: "Show me my active orders and their status",
          analyzePortfolio:
            "Analyze my DeFi portfolio and suggest optimizations",
        };

        const message = actionMessages[action];
        if (message) {
          await agent.sendMessage(message);
          return;
        }
      }

      // Fallback suggestions for when agent is not ready
      const suggestionResponses: Record<string, Partial<ChatMessageData>> = {
        checkBalance: {
          message:
            "🔍 **Balance Check**\n\nTo check your balances, I need to connect to the BitYield AI agent which provides real-time Hedera network data.\n\n⏳ **Current Status**: Establishing connection...\n\nOnce connected, I can show you:\n• HBAR balance\n• Token balances (USDC, SAUCE)\n• Pending transactions\n• Active order reserves",
          suggestions: [
            {
              text: "Retry connection",
              type: "info",
              action: "retryConnection",
            },
          ],
        },
        // ... other fallback responses
      };

      const response = suggestionResponses[action];
      if (response) {
        const aiMessage: ChatMessageData = {
          type: "bot",
          ...response,
          timestamp: new Date().toLocaleTimeString([], {
            hour: "2-digit",
            minute: "2-digit",
          }),
        } as ChatMessageData;

        setMessages((prev) => [...prev, aiMessage]);
      }
    },
    [getWalletInfo, agent]
  );

  return {
    inputMessage,
    setInputMessage,
    messages,
    isTyping,
    handleSendMessage,
    handleSuggestionClick,

    // Agent-specific functionality
    agentStatus: agent.status,
    connectAgent: agent.connect,
    disconnectAgent: agent.disconnect,
    clearMessages: agent.clearMessages,
  };
};
