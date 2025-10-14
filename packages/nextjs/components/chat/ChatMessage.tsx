// components/chat/ChatMessage.tsx
import React from "react";
import { Button } from "../ui/button";
import {
  Bot,
  User,
  TrendingUp,
  AlertTriangle,
  Info,
  Sparkles,
} from "lucide-react";

export interface ChatSuggestion {
  text: string;
  type: "success" | "warning" | "info" | "default";
  action: string;
}

export interface ChatMessageData {
  type: "bot" | "user" | "system";
  message: string;
  timestamp: string;
  suggestions?: ChatSuggestion[];
}

interface ChatMessageProps {
  message: ChatMessageData;
  onSuggestionClick: (action: string) => void;
}

const getSuggestionIcon = (type: string) => {
  switch (type) {
    case "success":
      return <TrendingUp className="h-4 w-4" />;
    case "warning":
      return <AlertTriangle className="h-4 w-4" />;
    case "info":
      return <Info className="h-4 w-4" />;
    default:
      return <Sparkles className="h-4 w-4" />;
  }
};

const getSuggestionColor = (type: string) => {
  switch (type) {
    case "success":
      return "bg-green-500/20 text-green-400 border-green-500/30 hover:bg-green-500/30";
    case "warning":
      return "bg-amber-500/20 text-amber-400 border-amber-500/30 hover:bg-amber-500/30";
    case "info":
      return "bg-blue-500/20 text-blue-400 border-blue-500/30 hover:bg-blue-500/30";
    default:
      return "bg-primary/20 text-primary border-primary/30 hover:bg-primary/30";
  }
};

export const ChatMessage: React.FC<ChatMessageProps> = ({
  message,
  onSuggestionClick,
}) => {
  return (
    <div
      className={`flex ${
        message.type === "user" ? "justify-end" : "justify-start"
      }`}
    >
      <div
        className={`max-w-[85%] ${message.type === "user" ? "order-1" : ""}`}
      >
        <div
          className={`flex items-start space-x-3 ${
            message.type === "user" ? "flex-row-reverse space-x-reverse" : ""
          }`}
        >
          <div
            className={`w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 ${
              message.type === "user"
                ? "bg-muted/30 border-2 border-muted"
                : "bg-gradient-to-br from-primary to-purple-500"
            }`}
          >
            {message.type === "user" ? (
              <User className="h-5 w-5 text-muted-foreground" />
            ) : (
              <img
                src="/BitYieldLogo.png"
                alt="BitYield Logo"
                className="rounded-full"
                width={40}
                height={40}
              />
            )}
          </div>

          <div className={`${message.type === "user" ? "text-right" : ""}`}>
            <div
              className={`p-4 rounded-2xl shadow-md ${
                message.type === "user"
                  ? "bg-primary text-primary-foreground border border-primary/30"
                  : "glass border border-border/30"
              }`}
            >
              <p className="text-sm leading-relaxed whitespace-pre-line">
                {message.message}
              </p>
            </div>

            {message.suggestions && (
              <div className="mt-4 space-y-2">
                <div className="text-xs text-muted-foreground mb-2">
                  Suggested actions:
                </div>
                <div className="flex flex-wrap gap-2">
                  {message.suggestions.map((suggestion, idx) => (
                    <Button
                      key={idx}
                      variant="outline"
                      size="sm"
                      className={`${getSuggestionColor(
                        suggestion.type
                      )} transition-all duration-200 hover:scale-105`}
                      onClick={() => onSuggestionClick(suggestion.action)}
                    >
                      {getSuggestionIcon(suggestion.type)}
                      {suggestion.text}
                    </Button>
                  ))}
                </div>
              </div>
            )}

            <div className="text-xs text-muted-foreground mt-2 opacity-70">
              {message.timestamp}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
