// src/ai/agent.mts

import "dotenv/config";
import * as readline from "readline";
import { ChatGoogleGenerativeAI } from "@langchain/google-genai";
import {
  HumanMessage,
  AIMessage,
  BaseMessage,
  ToolMessage,
} from "@langchain/core/messages";
import { StateGraph } from "@langchain/langgraph";
import { DynamicTool } from "@langchain/core/tools";

import {
  fetchStarknetBalance,
  displayStarknetBalance,
} from "../tools/starknet-balance.mts";
import {
  fetchBitcoinBalance,
  displayBitcoinBalance,
} from "../tools/bitcoin-balance.mts";
import {
  analyzeInvestment,
  displayInvestmentAnalysis,
} from "../tools/investment-analysis.mts";
import {
  executeInvestment,
  displayExecutionResult,
} from "../tools/investment-execute.mts";
import {
  displayAgentResponse,
  displaySeparator,
  displayError,
} from "../utils/display.mts";
import type { InvestmentAnalysis } from "../utils/types.mts";

interface AgentState {
  messages: BaseMessage[];
}

let investmentAnalysis: InvestmentAnalysis | null = null;

const starknetBalanceTool = new DynamicTool({
  name: "get_all_balance",
  description:
    "Fetches user balance on Starknet and BTC i.e. BTC, WBTC, STRK, USDC",
  func: async (input: string) => {
    const balance = await fetchStarknetBalance();
    const assets = await displayStarknetBalance(balance);

    return `📊 Your Assets Across Chains:\n\n${assets
      .map((a) => `${a.symbol}: ${a.amount} (${a.chain})`)
      .join("\n")}`;
  },
});


const bitcoinBalanceTool = new DynamicTool({
  name: "get_bitcoin_balance",
  description: "Fetches user Bitcoin L1 balance",
  func: async () => {
    const balance = await fetchBitcoinBalance();
    return await displayBitcoinBalance(balance);
  },
});

const analyzeInvestmentTool = new DynamicTool({
  name: "analyze_investment",
  description: "Analyzes investment strategy for BitYield protocol",
  func: async (input: string) => {
    const btcAmount = parseFloat(input) || 5;
    const analysis = await analyzeInvestment(btcAmount);
    investmentAnalysis = analysis;
    return await displayInvestmentAnalysis(analysis);
  },
});

const executeInvestmentTool = new DynamicTool({
  name: "execute_investment",
  description: "Executes the investment by depositing to Vesu and Troves",
  func: async (input: string) => {
    const confirmed =
      input.toLowerCase() === "yes" || input.toLowerCase() === "true";
    if (!investmentAnalysis) return "No analysis found";
    const result = await executeInvestment(investmentAnalysis, confirmed);
    return await displayExecutionResult(result);
  },
});

const tools = [
  starknetBalanceTool,
  bitcoinBalanceTool,
  analyzeInvestmentTool,
  executeInvestmentTool,
];

const model = new ChatGoogleGenerativeAI({
  model: "gemini-2.0-flash",
  temperature: 0,
});

async function processToolCall(
  toolName: string,
  toolInput: string
): Promise<string> {
  switch (toolName) {
    case "get_all_balance":
      return await starknetBalanceTool.func("");
    case "get_bitcoin_balance":
      return await bitcoinBalanceTool.func("");
    case "analyze_investment": {
      const amount = parseFloat(toolInput) || 5;
      return await analyzeInvestmentTool.func(amount.toString());
    }
    case "execute_investment": {
      const confirmed = toolInput.toLowerCase() === "true";
      return await executeInvestmentTool.func(confirmed.toString());
    }
    default:
      return `Unknown tool: ${toolName}`;
  }
}

async function callModel(state: AgentState) {
  const systemPrompt = `You are BitYield Protocol investment agent. You MUST follow this flow exactly:

FLOW:
1. If user asks about balance across all chains → Call ONLY: TOOL_CALL: get_all_balance() 
2. If user wants to invest (e.g., "i want invest 10 BTC") → Call ONLY: TOOL_CALL: analyze_investment(10) 
3. After analysis, wait for user response
4. If user says "yes", "confirm", "proceed" → Call ONLY: TOOL_CALL: execute_investment(true)
5. If user says "no", "cancel" → Do NOT call any tool, just respond friendly

STRICT RULES:
- NEVER call multiple tools in one response
- NEVER call analyze_investment unless user explicitly asks to invest
- NEVER call execute_investment unless user confirms with yes/confirm/proceed
- ONLY respond with TOOL_CALL when appropriate
- When NOT calling a tool, respond naturally to user

IMPORTANT: Look at actual user message and respond ONLY to what they're asking

CONTEXT FROM CONVERSATION:
${state.messages.map((m) => `${m._getType() === "human" ? "User" : "Assistant"}: ${typeof m.content === "string" ? m.content : ""}`).join("\n")}`;

  const messagesWithSystem = [
    new HumanMessage(systemPrompt),
    ...state.messages,
  ];

  const response = await model.invoke(messagesWithSystem);

  return { messages: [response] };
}

function shouldContinue(state: AgentState): string {
  const lastMessage = state.messages[state.messages.length - 1];
  if (lastMessage instanceof AIMessage) {
    const content = lastMessage.content as string;
    if (content.includes("TOOL_CALL:")) {
      return "tools";
    }
  }
  return "__end__";
}

async function toolNode(state: AgentState) {
  const lastMessage = state.messages[state.messages.length - 1] as AIMessage;
  const content = lastMessage.content as string;

  const match = content.match(/TOOL_CALL:\s*(\w+)\((.*?)\)/);
  if (!match) return { messages: [] };

  const [, toolName, args] = match;
  const result = await processToolCall(toolName, args);

  return {
    messages: [new HumanMessage(`Tool ${toolName} result:\n\n${result}`)],
  };
}

const workflow = new StateGraph<AgentState>({
  channels: {
    messages: {
      reducer: (currentState: BaseMessage[], updateValue: BaseMessage[]) =>
        currentState.concat(updateValue),
      default: () => [],
    },
  },
})
  .addNode("agent", callModel)
  .addNode("tools", toolNode)
  .addEdge("__start__", "agent")
  .addConditionalEdges("agent", shouldContinue, {
    tools: "tools",
    __end__: "__end__",
  })
  .addEdge("tools", "agent");

const app = workflow.compile();

async function main() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  const conversationHistory: BaseMessage[] = [];

  console.log("\n🤖 BitYield Agent - Powered by Gemini\n");
  console.log('Try: "Check my balance across chains", "i want to Invest 10 BTC", or "exit"\n');

  const askQuestion = () => {
    rl.question("You: ", async (input) => {
      if (input.toLowerCase() === "exit") {
        console.log("\nGoodbye!\n");
        rl.close();
        return;
      }

      try {
        const userMessage = new HumanMessage(input);
        conversationHistory.push(userMessage);

        const result = await app.invoke({
          messages: conversationHistory,
        });

        const allMessages = result.messages as BaseMessage[];
        const lastMessage = allMessages[allMessages.length - 1];

        if (lastMessage instanceof AIMessage) {
          displayAgentResponse(lastMessage.content as string);
          conversationHistory.push(lastMessage);
        }

        displaySeparator();
        askQuestion();
      } catch (error: any) {
        displayError(`Error: ${error.message}`);
        askQuestion();
      }
    });
  };

  askQuestion();
}

main().catch(console.error);
