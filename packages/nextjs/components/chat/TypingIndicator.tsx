import React from "react";
import { Bot } from "lucide-react";
import Image from "next/image";

interface TypingIndicatorProps {
  isVisible: boolean;
}

export const TypingIndicator: React.FC<TypingIndicatorProps> = ({
  isVisible,
}) => {
  if (!isVisible) return null;

  return (
    <div className="flex items-start gap-3 mb-6">
      <div className="w-10 h-10 rounded-full flex items-center justify-center flex-shrink-0 bg-gradient-to-br from-orange-500 to-purple-600">
        <Image
          src="/BitYieldLogo.png"
          alt="BitYield Logo"
          className="rounded-xl"
          width={40}
          height={40}
        />
      </div>
      <div className="bg-slate-900/50 border border-slate-800 p-4 rounded-2xl">
        <div className="flex items-center gap-2">
          <div className="flex gap-1">
            <div
              className="w-2 h-2 bg-purple-400 rounded-full animate-bounce"
              style={{ animationDelay: "0ms" }}
            />
            <div
              className="w-2 h-2 bg-purple-400 rounded-full animate-bounce"
              style={{ animationDelay: "150ms" }}
            />
            <div
              className="w-2 h-2 bg-purple-400 rounded-full animate-bounce"
              style={{ animationDelay: "300ms" }}
            />
          </div>
          <span className="text-sm text-slate-400">AI is thinking...</span>
        </div>
      </div>
    </div>
  );
};
