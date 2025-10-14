// hooks/useAgent.ts
import { useState, useEffect, useCallback } from 'react';
import { agentService } from '../services/agentService';

export interface AgentStatus {
  isConnected: boolean;
  isHealthy: boolean;
  isProcessing: boolean;
  error: string | null;
}

export interface AgentMessage {
  id: string;
  type: 'user' | 'agent' | 'system';
  content: string;
  timestamp: Date;
  status?: 'pending' | 'delivered' | 'error';
}

export const useAgent = () => {
  const [status, setStatus] = useState<AgentStatus>({
    isConnected: false,
    isHealthy: false,
    isProcessing: false,
    error: null,
  });
  
  const [messages, setMessages] = useState<AgentMessage[]>([]);
  const [sessionId] = useState(() => `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`);

  // Initialize connection
  const connect = useCallback(async () => {
    try {
      setStatus(prev => ({ ...prev, error: null }));
      
      // Check server health first
      const isHealthy = await agentService.checkHealth();
      if (!isHealthy) {
        throw new Error('YieldCraft AI server is not ready');
      }

      // Establish WebSocket connection
      await agentService.connect();
      
      setStatus(prev => ({ 
        ...prev, 
        isConnected: true, 
        isHealthy: true, 
        error: null 
      }));

      // Add welcome message from agent
      addSystemMessage('Connected to YieldCraft AI Agent. Ready to assist with your DeFi operations!');
      
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Connection failed';
      setStatus(prev => ({ 
        ...prev, 
        isConnected: false, 
        isHealthy: false, 
        error: errorMessage 
      }));
      
      addSystemMessage(`Connection failed: ${errorMessage}`, 'error');
    }
  }, []);

  // Send message to agent
  const sendMessage = useCallback(async (content: string): Promise<boolean> => {
    if (!content.trim()) return false;

    const userMessage: AgentMessage = {
      id: `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: 'user',
      content: content.trim(),
      timestamp: new Date(),
      status: 'pending',
    };

    setMessages(prev => [...prev, userMessage]);
    setStatus(prev => ({ ...prev, isProcessing: true, error: null }));

    try {
      // Try WebSocket first, fallback to HTTP
      let response;
      if (agentService.isConnected) {
        response = await agentService.sendMessage(content, sessionId);
      } else {
        response = await agentService.sendMessageHTTP(content);
      }

      // Update user message status
      setMessages(prev => 
        prev.map(msg => 
          msg.id === userMessage.id 
            ? { ...msg, status: 'delivered' as const }
            : msg
        )
      );

      // Add agent response
      const agentMessage: AgentMessage = {
        id: `agent_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        type: 'agent',
        content: response.message,
        timestamp: new Date(response.timestamp),
        status: 'delivered',
      };

      setMessages(prev => [...prev, agentMessage]);
      
      setStatus(prev => ({ ...prev, isProcessing: false }));
      return true;

    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Failed to send message';
      
      // Update user message status
      setMessages(prev => 
        prev.map(msg => 
          msg.id === userMessage.id 
            ? { ...msg, status: 'error' as const }
            : msg
        )
      );

      // Add error message
      addSystemMessage(`Error: ${errorMessage}`, 'error');
      
      setStatus(prev => ({ 
        ...prev, 
        isProcessing: false, 
        error: errorMessage 
      }));
      
      return false;
    }
  }, [sessionId]);

  // Add system messages
  const addSystemMessage = useCallback((content: string, type: 'info' | 'error' = 'info') => {
    const systemMessage: AgentMessage = {
      id: `system_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: 'system',
      content,
      timestamp: new Date(),
      status: 'delivered',
    };

    setMessages(prev => [...prev, systemMessage]);
  }, []);

  // Clear conversation
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
    addSystemMessage('Disconnected from YieldCraft AI Agent');
  }, [addSystemMessage]);

  // Auto-connect on mount
  useEffect(() => {
    connect();
    
    return () => {
      disconnect();
    };
  }, [connect, disconnect]);

  // Listen for agent status updates
  useEffect(() => {
    const handleStatus = (statusUpdate: any) => {
      if (statusUpdate.type === 'thinking') {
        setStatus(prev => ({ ...prev, isProcessing: true }));
      }
    };

    agentService.onStatus(handleStatus);
    
    return () => {
      agentService.offStatus(handleStatus);
    };
  }, []);

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