// components/chat/ChatMessages.tsx
import React from "react";
import { ChatMessage, ChatMessageData } from "./ChatMessage";
import { AgentChatMessage } from "../agent/AgentChatMessage";
import { TypingIndicator } from "./TypingIndicator";

interface ChatMessagesProps {
  messages: ChatMessageData[];
  agentMessages?: ChatMessageData[];
  isTyping: boolean;
  onSuggestionClick: (action: string) => void;
  useAgentMessages?: boolean;
  network?: 'mainnet' | 'testnet';
}

export const ChatMessages: React.FC<ChatMessagesProps> = ({
  messages,
  agentMessages = [],
  isTyping,
  onSuggestionClick,
  useAgentMessages = false,
  network = 'testnet',
}) => {
  console.log('messages', messages)
  return (
    <div className="flex-1 overflow-y-auto px-4 py-6">
      <div className="space-y-6">
        {useAgentMessages ? (
          // Render agent messages with  formatting, transaction links, and token displays
          messages.map((msg, index) => (
            <AgentChatMessage 
              key={index} 
              message={msg} 
              network={network}
            />
          ))
        ) : (
          // Render regular chat messages (fallback)
          messages.map((msg, index) => (
            <ChatMessage
              key={index}
              message={msg}
              onSuggestionClick={onSuggestionClick}
            />
          ))
        )}
        <TypingIndicator isVisible={isTyping} />
      </div>
    </div>
  );
};