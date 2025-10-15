import React from "react";
import { ChatMessages } from "./ChatMessages";
import { ChatInput } from "./ChatInput";
import { AlertCircle } from "lucide-react";
import { StarknetNetwork } from "~~/utils/tokenConfig";

interface ChatMessage {
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
interface AgentStatus {
  isConnected: boolean;
  isHealthy: boolean;
  isProcessing: boolean;
  error: string | null;
}

interface ChatAreaProps {
  messages: ChatMessage[];
  inputMessage: string;
  setInputMessage: (message: string) => void;
  onSendMessage: () => void;
  isTyping: boolean;
  onSuggestionClick: (action: string) => void;
  agentStatus?: AgentStatus;
  walletConnected?: boolean;
}

export const ChatArea: React.FC<ChatAreaProps> = ({
  messages,
  inputMessage,
  setInputMessage,
  onSendMessage,
  isTyping,
  onSuggestionClick,
  agentStatus,
  walletConnected = false,
}) => {
  const isReady =
    !agentStatus ||
    (agentStatus.isConnected &&
      agentStatus.isHealthy &&
      !agentStatus.isProcessing);

  return (
    <main className="flex-1 flex flex-col max-w-6xl mx-auto w-full">
      {/* Messages Area */}
      <div className="flex-1 overflow-y-auto px-6 py-6">
        <ChatMessages
          messages={messages}
          isTyping={isTyping}
          onSuggestionClick={onSuggestionClick}
        />
      </div>

      {/* Input Area */}
      <div className="border-t border-slate-800 bg-slate-950/50 backdrop-blur-lg px-6 py-4">
        <ChatInput
          inputMessage={inputMessage}
          setInputMessage={setInputMessage}
          onSendMessage={onSendMessage}
          isTyping={!isReady}
          walletConnected={walletConnected}
        />

        {/* Status Banners */}
        {agentStatus && !agentStatus.isConnected && (
          <div className="mt-3 px-4 py-2 bg-amber-500/10 border border-amber-500/30 rounded-lg">
            <div className="flex items-center gap-2 text-sm text-amber-300">
              <AlertCircle className="w-4 h-4" />
              <span>
                Agent is connecting... Some features may be unavailable.
              </span>
            </div>
          </div>
        )}

        {agentStatus && agentStatus.error && (
          <div className="mt-3 px-4 py-2 bg-red-500/10 border border-red-500/30 rounded-lg">
            <div className="flex items-center gap-2 text-sm text-red-300">
              <AlertCircle className="w-4 h-4" />
              <span>Agent error: {agentStatus.error}</span>
            </div>
          </div>
        )}

        {!walletConnected && (
          <div className="mt-3 px-4 py-2 bg-purple-500/10 border border-purple-500/30 rounded-lg">
            <div className="flex items-center gap-2 text-sm text-purple-300">
              <AlertCircle className="w-4 h-4" />
              <span>
                Connect your wallet to access deposit/withdraw features
              </span>
            </div>
          </div>
        )}
      </div>
    </main>
  );
};
