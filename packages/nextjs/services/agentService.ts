// services/agentService.ts
import { io, Socket } from 'socket.io-client';

interface AgentResponse {
  message: string;
  timestamp: string;
  sessionId?: string;
}

interface AgentError {
  message: string;
  timestamp: string;
}

interface AgentStatus {
  type: 'thinking' | 'ready' | 'error';
  message: string;
}

class AgentService {
  private socket: Socket | null = null;
  private readonly serverUrl: string;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectDelay = 1000;

  constructor(serverUrl = 'http://localhost:3001') {
    this.serverUrl = serverUrl;
  }

  connect(): Promise<boolean> {
    return new Promise((resolve, reject) => {
      if (this.socket?.connected) {
        resolve(true);
        return;
      }

      this.socket = io(this.serverUrl, {
        transports: ['websocket', 'polling'],
        timeout: 10000,
        reconnection: true,
        reconnectionAttempts: this.maxReconnectAttempts,
        reconnectionDelay: this.reconnectDelay,
      });

      this.socket.on('connect', () => {
        console.log('✅ Connected to YieldCraft AI Agent');
        this.reconnectAttempts = 0;
        resolve(true);
      });

      this.socket.on('connect_error', (error) => {
        console.error('❌ Agent connection failed:', error);
        reject(error);
      });

      this.socket.on('disconnect', (reason) => {
        console.log('🔌 Disconnected from agent:', reason);
        this.handleReconnection();
      });

      // Set connection timeout
      setTimeout(() => {
        if (!this.socket?.connected) {
          reject(new Error('Connection timeout'));
        }
      }, 10000);
    });
  }

  private handleReconnection() {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      console.log(`🔄 Attempting to reconnect... (${this.reconnectAttempts}/${this.maxReconnectAttempts})`);
    }
  }

  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
  }

  // WebSocket-based messaging
  sendMessage(message: string, sessionId?: string): Promise<AgentResponse> {
    return new Promise((resolve, reject) => {
      if (!this.socket?.connected) {
        reject(new Error('Not connected to agent server'));
        return;
      }

      const timeout = setTimeout(() => {
        reject(new Error('Agent response timeout'));
      }, 45000);

      this.socket.emit('message', { message, sessionId });

      this.socket.once('response', (response: AgentResponse) => {
        clearTimeout(timeout);
        resolve(response);
      });

      this.socket.once('error', (error: AgentError) => {
        clearTimeout(timeout);
        reject(new Error(error.message || 'Agent error'));
      });
    });
  }

  // REST API fallback
  async sendMessageHTTP(message: string): Promise<AgentResponse> {
    const response = await fetch(`${this.serverUrl}/api/chat`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ message }),
    });

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new Error(errorData.error || `HTTP ${response.status}`);
    }

    const data = await response.json();
    return {
      message: data.response,
      timestamp: data.timestamp,
    };
  }

  // Status monitoring
  onStatus(callback: (status: AgentStatus) => void) {
    if (this.socket) {
      this.socket.on('status', callback);
    }
  }

  offStatus(callback: (status: AgentStatus) => void) {
    if (this.socket) {
      this.socket.off('status', callback);
    }
  }

  // Health check
  async checkHealth(): Promise<boolean> {
    try {
      const response = await fetch(`${this.serverUrl}/api/health`);
      const data = await response.json();
      return data.status === 'healthy' && data.agent === 'ready';
    } catch (error) {
      console.error('Health check failed:', error);
      return false;
    }
  }

  get isConnected(): boolean {
    return this.socket?.connected || false;
  }
}

export const agentService = new AgentService();