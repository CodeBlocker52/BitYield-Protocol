import React from "react";
import { Send, Loader2 } from "lucide-react";

interface ChatInputProps {
  inputMessage: string;
  setInputMessage: (message: string) => void;
  onSendMessage: () => void;
  isTyping: boolean;
  walletConnected?: boolean;
}

export const ChatInput: React.FC<ChatInputProps> = ({
  inputMessage,
  setInputMessage,
  onSendMessage,
  isTyping,
  walletConnected = false,
}) => {
  const quickActions = [
    { label: "Best yields", message: "Show me the best yield opportunities" },
    { label: "Risk analysis", message: "What are the risks?" },
    { label: "Auto-compound", message: "Set up auto-compounding" },
    { label: "Portfolio", message: "Analyze my portfolio" },
  ];

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      onSendMessage();
    }
  };

  return (
    <div>
      {/* Quick Actions */}
      <div className="flex flex-wrap gap-2 mb-4">
        {quickActions.map((action, idx) => (
          <button
            key={idx}
            onClick={() => setInputMessage(action.message)}
            className="px-3 py-1.5 bg-slate-800/50 border border-slate-700 rounded-lg text-xs text-slate-300 hover:bg-slate-800 hover:border-purple-500/50 transition-all"
          >
            &quot;{action.label}&quot;
          </button>
        ))}
      </div>

      {/* Input Field */}
      <div className="flex items-center gap-3">
        <input
          type="text"
          value={inputMessage}
          onChange={(e) => setInputMessage(e.target.value)}
          onKeyPress={handleKeyPress}
          placeholder="Ask about yield strategies, risk analysis, portfolio optimization..."
          className="flex-1 px-4 py-3 bg-slate-900/50 border border-slate-800 rounded-xl text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-purple-500/50 focus:border-transparent transition-all"
          disabled={isTyping}
        />
        <button
          onClick={onSendMessage}
          disabled={!inputMessage.trim() || isTyping}
          className="px-6 py-3 bg-gradient-to-r from-orange-500 to-purple-600 rounded-xl font-semibold hover:shadow-lg hover:shadow-purple-500/50 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
        >
          {isTyping ? (
            <Loader2 className="w-5 h-5 animate-spin" />
          ) : (
            <Send className="w-5 h-5" />
          )}
        </button>
      </div>
    </div>
  );
};
