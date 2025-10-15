// ============================================
// FILE 1: services/agentService.ts
// Socket.IO client for Node.js backend
// ============================================

import { io, Socket } from 'socket.io-client';

const API_BASE_URL = process.env.VITE_AGENT_API_URL || 'http://localhost:8000';

export interface AgentResponse {
  message: string;
  timestamp: string;
  metadata?: {
    action?: string;
    data?: any;
  };
}

export interface AgentEvent {
  type: 'loading' | 'success' | 'error' | 'info' | 'progress' | 'transaction';
  message?: string;
  step?: number;
  total?: number;
  description?: string;
  txHash?: string;
  timestamp: string;
}

class AgentService {
  private socket: Socket | null = null;
  private sessionId: string | null = null;
  private messageHandlers: ((response: AgentResponse) => void)[] = [];
  private eventHandlers: ((event: AgentEvent) => void)[] = [];

  /**
   * Check if agent service is healthy
   */
  async checkHealth(): Promise<boolean> {
    try {
      const response = await fetch(`${API_BASE_URL}/health`);
      return response.ok;
    } catch (error) {
      console.error('Health check failed:', error);
      return false;
    }
  }

  /**
   * Connect to Socket.IO server
   */
  async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        this.socket = io(API_BASE_URL, {
          transports: ['websocket', 'polling'],
          reconnection: true,
          reconnectionAttempts: 5,
          reconnectionDelay: 1000,
        });

        // Connection successful
        this.socket.on('connected', (data: any) => {
          console.log('✅ Connected to BitYield Agent:', data.sessionId);
          this.sessionId = data.sessionId;
          resolve();
        });

        // Handle different event types
        this.socket.on('agent:loading', (event: AgentEvent) => {
          this.eventHandlers.forEach(handler => handler(event));
        });

        this.socket.on('agent:success', (event: AgentEvent) => {
          this.eventHandlers.forEach(handler => handler(event));
        });

        this.socket.on('agent:error', (event: AgentEvent) => {
          this.eventHandlers.forEach(handler => handler(event));
        });

        this.socket.on('agent:info', (event: AgentEvent) => {
          this.eventHandlers.forEach(handler => handler(event));
        });

        this.socket.on('agent:progress', (event: AgentEvent) => {
          this.eventHandlers.forEach(handler => handler(event));
        });

        this.socket.on('agent:transaction', (event: AgentEvent) => {
          this.eventHandlers.forEach(handler => handler(event));
        });

        // Final response
        this.socket.on('agent:response', (data: any) => {
          const response: AgentResponse = data.payload;
          this.messageHandlers.forEach(handler => handler(response));
        });

        // Connection error
        this.socket.on('connect_error', (error) => {
          console.error('Connection error:', error);
          reject(error);
        });

        // Disconnection
        this.socket.on('disconnect', () => {
          console.log('❌ Disconnected from BitYield Agent');
        });

      } catch (error) {
        reject(error);
      }
    });
  }

  /**
   * Send message via Socket.IO
   */
  async sendMessage(content: string): Promise<AgentResponse> {
    return new Promise((resolve, reject) => {
      if (!this.socket || !this.socket.connected) {
        reject(new Error('Socket not connected'));
        return;
      }

      // Set up one-time response handler
      const responseHandler = (response: AgentResponse) => {
        this.messageHandlers = this.messageHandlers.filter(h => h !== responseHandler);
        resolve(response);
      };

      this.messageHandlers.push(responseHandler);

      // Send message
      this.socket.emit('message', { content });

      // Timeout after 30 seconds
      setTimeout(() => {
        this.messageHandlers = this.messageHandlers.filter(h => h !== responseHandler);
        reject(new Error('Request timeout'));
      }, 30000);
    });
  }

  /**
   * Send message via HTTP (fallback)
   */
  async sendMessageHTTP(content: string, context?: any): Promise<AgentResponse> {
    try {
      const response = await fetch(`${API_BASE_URL}/chat`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          message: content,
          session_id: this.sessionId,
          context,
        }),
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      return {
        message: data.response || data.message,
        timestamp: data.timestamp || new Date().toISOString(),
        metadata: data.metadata,
      };
    } catch (error) {
      console.error('HTTP request failed:', error);
      throw error;
    }
  }

  /**
   * Get vault analytics
   */
  async getVaultAnalytics(): Promise<any> {
    try {
      const response = await fetch(`${API_BASE_URL}/analytics/vault`);
      if (!response.ok) throw new Error('Failed to fetch analytics');
      return await response.json();
    } catch (error) {
      console.error('Analytics fetch failed:', error);
      throw error;
    }
  }

  /**
   * Get portfolio recommendations
   */
  async getRecommendations(userAddress: string): Promise<any> {
    try {
      const response = await fetch(`${API_BASE_URL}/recommendations/${userAddress}`);
      if (!response.ok) throw new Error('Failed to fetch recommendations');
      return await response.json();
    } catch (error) {
      console.error('Recommendations fetch failed:', error);
      throw error;
    }
  }

  /**
   * Subscribe to agent events (loading, success, error, etc.)
   */
  onEvent(handler: (event: AgentEvent) => void): void {
    this.eventHandlers.push(handler);
  }

  /**
   * Unsubscribe from events
   */
  offEvent(handler: (event: AgentEvent) => void): void {
    this.eventHandlers = this.eventHandlers.filter(h => h !== handler);
  }

  /**
   * Disconnect Socket.IO
   */
  disconnect(): void {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
    this.messageHandlers = [];
    this.eventHandlers = [];
    this.sessionId = null;
  }

  /**
   * Check if Socket.IO is connected
   */
  get isConnected(): boolean {
    return this.socket !== null && this.socket.connected;
  }
}

// Export singleton instance
export const agentService = new AgentService();



// ============================================
// FILE 5: Example Usage in React Component
// ============================================

/*
import React, { useState } from 'react';
import { useAgent } from '@/hooks/useAgent';

export default function ChatPage() {
  const agent = useAgent();
  const [input, setInput] = useState('');

  const handleSend = async () => {
    if (!input.trim()) return;
    
    await agent.sendMessage(input);
    setInput('');
  };

  return (
    <div className="chat-container">
      <div className="status-bar">
        {agent.status.isConnected ? (
          <span className="text-green-500">● Connected</span>
        ) : (
          <span className="text-red-500">● Disconnected</span>
        )}
      </div>

      <div className="messages">
        {agent.messages.map((msg) => (
          <div key={msg.id} className={`message message-${msg.type}`}>
            <div className="content">{msg.content}</div>
            <div className="timestamp">
              {msg.timestamp.toLocaleTimeString()}
            </div>
          </div>
        ))}
      </div>

      <div className="input-area">
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyPress={(e) => e.key === 'Enter' && handleSend()}
          placeholder="Type your message..."
          disabled={!agent.isReady}
        />
        <button onClick={handleSend} disabled={!agent.isReady}>
          Send
        </button>
      </div>

      {agent.status.error && (
        <div className="error-banner">{agent.status.error}</div>
      )}
    </div>
  );
}
*/