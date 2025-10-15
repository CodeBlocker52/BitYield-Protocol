import React from "react";
import { ChatMessage } from "./ChatMessage";
import { TypingIndicator } from "./TypingIndicator";
import { StarknetNetwork } from "~~/utils/tokenConfig";

interface Message {
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

interface ChatMessagesProps {
  messages: Message[];
  isTyping: boolean;
  onSuggestionClick: (action: string) => void;
}

export const ChatMessages: React.FC<ChatMessagesProps> = ({
  messages,
  isTyping,
  onSuggestionClick,
}) => {
  return (
    <div className="space-y-6">
      {messages.map((msg) => (
        <ChatMessage
          key={msg.id}
          message={msg}
          onSuggestionClick={onSuggestionClick}
        />
      ))}
      <TypingIndicator isVisible={isTyping} />
    </div>
  );
};
