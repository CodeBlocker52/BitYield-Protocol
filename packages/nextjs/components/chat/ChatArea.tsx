// components/chat/ChatArea.tsx
import React from "react";
import { ChatMessages } from "./ChatMessages";
import { ChatInput } from "./ChatInput";
import { ChatMessageData } from "./ChatMessage";
import { AgentMessage, AgentStatus } from "../../hooks/useAgent";

interface ChatAreaProps {
  messages: ChatMessageData[];
  agentMessages?: AgentMessage[];
  inputMessage: string;
  setInputMessage: (message: string) => void;
  onSendMessage: () => void;
  isTyping: boolean;
  onSuggestionClick: (action: string) => void;
  agentStatus?: AgentStatus;
  useAgentMessages?: boolean;
  network?: 'mainnet' | 'testnet' | 'previewnet';
}

export const ChatArea: React.FC<ChatAreaProps> = ({
  messages,
  agentMessages,
  inputMessage,
  setInputMessage,
  onSendMessage,
  isTyping,
  onSuggestionClick,
  agentStatus,
  useAgentMessages = false,
  network = 'testnet',
}) => {
  const isReady = !agentStatus || (agentStatus.isConnected && agentStatus.isHealthy && !agentStatus.isProcessing);

  return (
    <main className="flex-1 flex flex-col">
      <div className="flex-1 flex flex-col max-w-4xl mx-auto w-full">
        <ChatMessages
          messages={messages}
          agentMessages={agentMessages}
          isTyping={isTyping}
          onSuggestionClick={onSuggestionClick}
          useAgentMessages={useAgentMessages}
          network={network}
        />
        <ChatInput
          inputMessage={inputMessage}
          setInputMessage={setInputMessage}
          onSendMessage={onSendMessage}
          isTyping={!isReady}
        />
        
        {/* Agent Status Footer */}
        {agentStatus && !agentStatus.isConnected && (
          <div className="px-4 py-2 bg-amber-500/10 border-t border-amber-500/20">
            <div className="text-center text-sm text-amber-600">
              Agent is connecting... Some advanced features may be unavailable.
            </div>
          </div>
        )}
        
        {agentStatus && agentStatus.error && (
          <div className="px-4 py-2 bg-red-500/10 border-t border-red-500/20">
            <div className="text-center text-sm text-red-600">
              Agent error: {agentStatus.error}
            </div>
          </div>
        )}
      </div>
    </main>
  );
};