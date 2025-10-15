import { useState, useEffect, useCallback } from "react";
import {
  agentService,
  AgentResponse,
  AgentEvent,
} from "../services/agentService";

export interface AgentStatus {
  isConnected: boolean;
  isHealthy: boolean;
  isProcessing: boolean;
  error: string | null;
}

export interface AgentMessage {
  id: string;
  type: "user" | "bot" | "system" | "event";
  content: string;
  timestamp: Date;
  metadata?: any;
  suggestions?: Array<{
    text: string;
    action: string;
    type: "info" | "success" | "warning";
  }>;
}

export const useAgent = () => {
  const [status, setStatus] = useState<AgentStatus>({
    isConnected: false,
    isHealthy: false,
    isProcessing: false,
    error: null,
  });

  const [messages, setMessages] = useState<AgentMessage[]>([]);
  const [sessionId] = useState(
    () => `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`
  );

  // Add system message
  const addSystemMessage = useCallback(
    (content: string, type: "system" | "event" = "system") => {
      const systemMessage: AgentMessage = {
        id: `${type}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        type,
        content,
        timestamp: new Date(),
      };

      setMessages((prev) => [...prev, systemMessage]);
    },
    []
  );

  // Initialize connection
  const connect = useCallback(async () => {
    try {
      setStatus((prev) => ({ ...prev, error: null }));

      // Check health first
      const isHealthy = await agentService.checkHealth();
      if (!isHealthy) {
        throw new Error("BitYield Agent service is not available");
      }

      // Connect Socket.IO
      await agentService.connect();

      setStatus({
        isConnected: true,
        isHealthy: true,
        isProcessing: false,
        error: null,
      });

      addSystemMessage("✅ Connected to BitYield AI Agent");
    } catch (error) {
      const errorMessage =
        error instanceof Error ? error.message : "Connection failed";
      setStatus({
        isConnected: false,
        isHealthy: false,
        isProcessing: false,
        error: errorMessage,
      });

      addSystemMessage(`❌ Connection failed: ${errorMessage}`);
    }
  }, [addSystemMessage]);

  // Send message to agent
  const sendMessage = useCallback(
    async (content: string): Promise<boolean> => {
      if (!content.trim()) return false;

      const userMessage: AgentMessage = {
        id: `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        type: "user",
        content: content.trim(),
        timestamp: new Date(),
      };

      setMessages((prev) => [...prev, userMessage]);
      setStatus((prev) => ({ ...prev, isProcessing: true, error: null }));

      try {
        let response: AgentResponse;

        // Try Socket.IO first, fallback to HTTP
        if (agentService.isConnected) {
          response = await agentService.sendMessage(content);
        } else {
          response = await agentService.sendMessageHTTP(content);
        }

        // Add agent response
        const botMessage: AgentMessage = {
          id: `bot_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
          type: "bot",
          content: response.message,
          timestamp: new Date(response.timestamp),
          metadata: response.metadata,
          suggestions: response.metadata?.data || [],
        };

        setMessages((prev) => [...prev, botMessage]);
        setStatus((prev) => ({ ...prev, isProcessing: false }));
        return true;
      } catch (error) {
        const errorMessage =
          error instanceof Error ? error.message : "Failed to send message";

        addSystemMessage(`❌ Error: ${errorMessage}`);

        setStatus((prev) => ({
          ...prev,
          isProcessing: false,
          error: errorMessage,
        }));

        return false;
      }
    },
    [addSystemMessage]
  );

  // Clear messages
  const clearMessages = useCallback(() => {
    setMessages([]);
  }, []);

  // Disconnect
  const disconnect = useCallback(() => {
    agentService.disconnect();
    setStatus({
      isConnected: false,
      isHealthy: false,
      isProcessing: false,
      error: null,
    });
    addSystemMessage("Disconnected from BitYield AI Agent");
  }, [addSystemMessage]);

  // Auto-connect on mount
  useEffect(() => {
    connect();

    return () => {
      disconnect();
    };
  }, [connect, disconnect]);

  // Listen for agent events
  useEffect(() => {
    const handleEvent = (event: AgentEvent) => {
      switch (event.type) {
        case "loading":
          addSystemMessage(`⏳ ${event.message}`, "event");
          setStatus((prev) => ({ ...prev, isProcessing: true }));
          break;

        case "success":
          addSystemMessage(`✅ ${event.message}`, "event");
          break;

        case "error":
          addSystemMessage(`❌ ${event.message}`, "event");
          break;

        case "info":
          addSystemMessage(`ℹ️ ${event.message}`, "event");
          break;

        case "progress":
          addSystemMessage(
            `📊 Step ${event.step}/${event.total}: ${event.message}`,
            "event"
          );
          break;

        case "transaction":
          const txMessage: AgentMessage = {
            id: `tx_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            type: "bot", // treat as a bot message
            content: `📝 ${event.description}\n🔗 TX: ${event.txHash}`,
            timestamp: new Date(),
            metadata: {
              txHash: event.txHash,
              network: "sepolia",
            },
          };
          setMessages((prev) => [...prev, txMessage]);
          break;
      }
    };

    agentService.onEvent(handleEvent);

    return () => {
      agentService.offEvent(handleEvent);
    };
  }, [addSystemMessage]);

  return {
    // Status
    status,

    // Messages
    messages,

    // Actions
    sendMessage,
    clearMessages,
    connect,
    disconnect,

    // Utilities
    sessionId,
    isReady: status.isConnected && status.isHealthy && !status.isProcessing,
  };
};
