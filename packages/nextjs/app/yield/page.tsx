"use client";

import React from "react";
// import { useWallet } from "@/hooks/useHederaWallet";
import { useChatService } from "../../hooks/useChatService";
// import { useAppKitContext } from "@/context/AppKitContext";
import { ChatArea } from "~~/components/chat/ChatArea";

const Yield: React.FC = () => {
  // const { isInitialized } = useAppKitContext();
  // const wallet = useWallet();

  // Only call wallet hooks after AppKit is initialized
  const walletState = {
    isConnected: false,
    error: null,
    chainId: null,
  };

  const chatService = useChatService();

  // Determine network based on wallet connection
  const getNetwork = (): "mainnet" | "testnet" => {
    if (!walletState.chainId) return "testnet";

    switch (walletState.chainId) {
      case 295:
      case "295":
        return "mainnet";
      case 296:
      case "296":
        return "testnet";
      default:
        return "testnet";
    }
  };

  // Show loading state while AppKit initializes
  // if (!isInitialized) {
  //   return <LoadingScreen message="Initializing BitYield AI..." />;
  // }

  const { isConnected, error } = walletState;

  // Wallet Not Connected State - Welcome/Landing View
  // if (!isConnected) {
  //   return (
  //     <div>
  //       <ErrorBanner error={error} className="mx-4 mt-4" />
  //       <WelcomeLanding />
  //     </div>
  //   );
  // }

  // Wallet Connected State -  Chat Interface with Transaction Links and Token Display
  return (
    <div className="min-h-screen flex flex-col bg-background">
      {/* <ConnectedHeader 
        agentStatus={chatService.agentStatus}
        onReconnectAgent={chatService.connectAgent}
      />
      <ErrorBanner error={error} className="mx-4 mt-4" /> */}
      <ChatArea
        messages={chatService.messages}
        inputMessage={chatService.inputMessage}
        setInputMessage={chatService.setInputMessage}
        onSendMessage={chatService.handleSendMessage}
        isTyping={chatService.isTyping}
        onSuggestionClick={chatService.handleSuggestionClick}
        agentStatus={chatService.agentStatus}
        useAgentMessages={false} // Disable agent message display
        network={getNetwork()} // Pass detected network for proper HashScan links
      />
    </div>
  );
};

export default Yield;
