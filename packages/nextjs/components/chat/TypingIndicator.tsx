// components/chat/TypingIndicator.tsx
import React from "react";

interface TypingIndicatorProps {
  isVisible: boolean;
}

export const TypingIndicator: React.FC<TypingIndicatorProps> = ({
  isVisible,
}) => {
  if (!isVisible) return null;

  return (
    <div className="flex justify-start">
      <div className="flex items-start space-x-3">
        <div className="w-10 h-10 rounded-full bg-gradient-to-br from-primary to-purple-500 flex items-center justify-center">
          <img
            src="/BitYieldLogo.png"
            alt="BitYield Logo"
            width={70}
            height={70}
          />
        </div>
        <div className="glass p-4 rounded-2xl border border-border/30">
          <div className="flex items-center space-x-2">
            <div className="flex space-x-1">
              <div className="w-2 h-2 bg-primary rounded-full animate-bounce"></div>
              <div
                className="w-2 h-2 bg-primary rounded-full animate-bounce"
                style={{ animationDelay: "0.1s" }}
              ></div>
              <div
                className="w-2 h-2 bg-primary rounded-full animate-bounce"
                style={{ animationDelay: "0.2s" }}
              ></div>
            </div>
            <span className="text-sm text-muted-foreground">
              AI is thinking...
            </span>
          </div>
        </div>
      </div>
    </div>
  );
};
