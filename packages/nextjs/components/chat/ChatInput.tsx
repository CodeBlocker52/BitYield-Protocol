// components/chat/ChatInput.tsx
import React from "react";
import {Button} from "../ui/button";
import { Send } from "lucide-react";
import { Input } from "../ui/input";

interface ChatInputProps {
  inputMessage: string;
  setInputMessage: (message: string) => void;
  onSendMessage: () => void;
  isTyping: boolean;
}

export const ChatInput: React.FC<ChatInputProps> = ({
  inputMessage,
  setInputMessage,
  onSendMessage,
  isTyping,
}) => {
  const quickActions = [
    "Find me the best stablecoin yields",
    "What are the risks of liquidity providing?",
    "Set up auto-compounding for my positions",
    "Show me Bitcoin native opportunities",
  ];

  const quickActionLabels = [
    "Find best stablecoin yields",
    "What are LP risks?",
    "Setup auto-compound",
    "Bitcoin opportunities",
  ];

  return (
    <div className="border-t border-border/50 bg-background/95 backdrop-blur-sm px-4 py-4">
      <div className="flex space-x-3 mb-3">
        <Input
          placeholder="Ask about yield strategies, risk analysis, portfolio optimization..."
          value={inputMessage}
          onChange={(e) => setInputMessage(e.target.value)}
          onKeyPress={(e) =>
            e.key === "Enter" && !e.shiftKey && onSendMessage()
          }
          className="flex-1 glass border-primary/20 focus:border-primary/40 h-12"
          disabled={isTyping}
        />
        <Button
          variant="default"
          onClick={onSendMessage}
          disabled={!inputMessage.trim() || isTyping}
          className="h-12 px-6"
        >
          <Send className="h-5 w-5" />
        </Button>
      </div>

      {/* Quick Actions */}
      <div className="flex flex-wrap gap-2">
        {quickActions.map((action, index) => (
          <Button
            key={index}
            variant="ghost"
            size="sm"
            className="text-xs hover:bg-primary/10"
            onClick={() => setInputMessage(action)}
          >
            &quot;{quickActionLabels[index]}&quot;
          </Button>
        ))}
      </div>
    </div>
  );
};