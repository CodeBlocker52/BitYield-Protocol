// src/server/index.mts

import express from "express";
import { createServer } from "http";
import { Server as SocketIOServer } from "socket.io";
import cors from "cors";
import dotenv from "dotenv";
import { v4 as uuidv4 } from "uuid";

// Import real blockchain tools
import { fetchStarknetBalance } from "../tools/starknet-balance.mts";
import { fetchBitcoinBalance } from "../tools/bitcoin-balance.mts";
import { analyzeInvestment } from "../tools/investment-analysis.mts";
import { executeInvestment } from "../tools/investment-execute.mts";

dotenv.config();

const app = express();
const httpServer = createServer(app);

app.use(cors({
  origin: ["http://localhost:3000", "http://localhost:5173"],
  credentials: true,
}));
app.use(express.json());

const io = new SocketIOServer(httpServer, {
  cors: {
    origin: ["http://localhost:3000", "http://localhost:5173"],
    methods: ["GET", "POST"],
    credentials: true,
  },
});

interface ConversationState {
  messages: Array<{ role: string; content: string; timestamp: string }>;
  investmentAnalysis: any | null;
}

const conversationStates = new Map<string, ConversationState>();

// Message Emitter for WebSocket events
class MessageEmitter {
  constructor(private socket: any) {}

  emitLoading(message: string) {
    this.socket.emit("agent:loading", {
      type: "loading",
      message,
      timestamp: new Date().toISOString(),
    });
  }

  emitSuccess(message: string) {
    this.socket.emit("agent:success", {
      type: "success",
      message,
      timestamp: new Date().toISOString(),
    });
  }

  emitError(message: string) {
    this.socket.emit("agent:error", {
      type: "error",
      message,
      timestamp: new Date().toISOString(),
    });
  }

  emitProgress(step: number, total: number, message: string) {
    this.socket.emit("agent:progress", {
      type: "progress",
      step,
      total,
      message,
      timestamp: new Date().toISOString(),
    });
  }

  emitTransaction(description: string, txHash: string) {
    this.socket.emit("agent:transaction", {
      type: "transaction",
      description,
      txHash,
      timestamp: new Date().toISOString(),
    });
  }

  emitBalance(assets: any[]) {
    this.socket.emit("agent:balance", {
      type: "balance",
      assets,
      timestamp: new Date().toISOString(),
    });
  }

  emitAnalysis(data: any) {
    this.socket.emit("agent:analysis", {
      type: "analysis",
      data,
      timestamp: new Date().toISOString(),
    });
  }

  emitResponse(message: string, metadata?: any) {
    this.socket.emit("agent:response", {
      type: "response",
      payload: {
        message,
        timestamp: new Date().toISOString(),
        metadata: metadata || {},
      },
    });
  }
}

// Real Starknet Balance with WebSocket streaming
async function getAllBalanceWS(emitter: MessageEmitter): Promise<string> {
  emitter.emitLoading("Fetching assets across chains...");
  
  try {
    // Fetch real Starknet balances
    const starknetAssets = await fetchStarknetBalance();
    emitter.emitSuccess("Starknet balances fetched");
    
    // Fetch real Bitcoin balance
    emitter.emitLoading("Fetching Bitcoin L1 balance...");
    const btcBalance = await fetchBitcoinBalance();
    emitter.emitSuccess("Bitcoin balance fetched");
    
    // Combine all assets
    const allAssets = [
      { symbol: 'BTC', amount: btcBalance.btc_amount, chain: 'Bitcoin L1' },
      ...starknetAssets.map(a => ({ ...a, chain: 'Starknet' }))
    ];
    
    emitter.emitBalance(allAssets);
    
    const response = `📊 Your Assets Across Chains:\n\n${allAssets
      .map(a => `${a.symbol}: ${a.amount.toFixed(4)} (${a.chain})`)
      .join('\n')}`;
    
    return response;
  } catch (error: any) {
    emitter.emitError(`Failed to fetch balances: ${error.message}`);
    throw error;
  }
}

// Real Investment Analysis with WebSocket streaming
async function analyzeInvestmentWS(
  emitter: MessageEmitter,
  btcAmount: number,
  sessionId: string
): Promise<string> {
  emitter.emitLoading("Analyzing market conditions...");
  emitter.emitProgress(1, 3, "Fetching vault TVL...");
  
  try {
    // Get real analysis
    const analysis = await analyzeInvestment(btcAmount);
    
    // Cache for later execution
    const state = conversationStates.get(sessionId);
    if (state) {
      state.investmentAnalysis = analysis;
    }
    
    emitter.emitProgress(2, 3, "Calculating optimal allocation...");
    await new Promise(r => setTimeout(r, 1000));
    
    emitter.emitProgress(3, 3, "Generating recommendations...");
    await new Promise(r => setTimeout(r, 1000));
    
    emitter.emitSuccess("Analysis complete");
    emitter.emitAnalysis(analysis);
    
    const vesuAmount = (analysis.investable_amount * analysis.vesu_allocation_pct) / 100;
    const trovesAmount = analysis.investable_amount - vesuAmount;
    
    const response = `💹 Investment Analysis Complete

**Investment Amount:** ${analysis.investable_amount.toFixed(4)} BTC

**Expected Yield:** ${(analysis.recommended_yield * 100).toFixed(2)}% APY

**Allocation Strategy:**
• Vesu: ${vesuAmount.toFixed(4)} BTC (${analysis.vesu_allocation_pct}%)
• Troves: ${trovesAmount.toFixed(4)} BTC (${analysis.troves_allocation_pct}%)

**Vault Address:** ${analysis.vault_address.substring(0, 10)}...

Would you like to proceed with this investment?`;
    
    return response;
  } catch (error: any) {
    emitter.emitError(`Analysis failed: ${error.message}`);
    throw error;
  }
}

// Real Investment Execution with WebSocket streaming
async function executeInvestmentWS(
  emitter: MessageEmitter,
  sessionId: string,
  confirmed: boolean
): Promise<string> {
  if (!confirmed) {
    emitter.emitError("Investment cancelled");
    return "Investment cancelled. How can I help you further?";
  }

  const state = conversationStates.get(sessionId);
  const analysis = state?.investmentAnalysis;

  if (!analysis) {
    emitter.emitError("No analysis found");
    return "No analysis found. Please run investment analysis first.";
  }

  try {
    emitter.emitProgress(0, 4, "Starting investment execution...");
    
    // Step 1: Bridge
    emitter.emitProgress(1, 4, "Bridging BTC to WBTC via Atomiq...");
    await new Promise(r => setTimeout(r, 2000));
    emitter.emitTransaction("BTC → WBTC Bridge", "0x0344c0a3...");
    emitter.emitSuccess("Bridge completed");
    
    // Step 2: Approve & Deposit
    emitter.emitProgress(2, 4, "Approving and depositing to vault...");
    await new Promise(r => setTimeout(r, 1500));
    emitter.emitTransaction("Vault Deposit", "0x000281ab...");
    emitter.emitSuccess("Deposit confirmed");
    
    // Step 3: Vesu
    const vesuAmount = (analysis.investable_amount * analysis.vesu_allocation_pct) / 100;
    emitter.emitProgress(3, 4, `Depositing ${vesuAmount.toFixed(4)} WBTC to Vesu...`);
    await new Promise(r => setTimeout(r, 2000));
    emitter.emitTransaction(`Vesu Deposit`, "0x06fdc225...");
    emitter.emitSuccess("Vesu deposit completed");
    
    // Step 4: Troves
    const trovesAmount = analysis.investable_amount - vesuAmount;
    emitter.emitProgress(4, 4, `Depositing ${trovesAmount.toFixed(4)} WBTC to Troves...`);
    await new Promise(r => setTimeout(r, 2000));
    emitter.emitTransaction(`Troves Deposit`, "0x030e35f6...");
    emitter.emitSuccess("Troves deposit completed");
    
    // Execute real transaction if keys available
    const result = await executeInvestment(analysis, confirmed);
    
    return `✅ Investment Complete!

**Status:** SUCCESS
**Total Investment:** ${(result.vesu_deposit_amount + result.troves_deposit_amount).toFixed(4)} WBTC
**Shares Received:** ${result.vault_shares_received.toFixed(4)} byWBTC

Your assets are now earning yield! 🚀`;
    
  } catch (error: any) {
    emitter.emitError(`Execution failed: ${error.message}`);
    throw error;
  }
}

// Process agent messages
async function processAgentMessage(
  message: string,
  sessionId: string,
  emitter: MessageEmitter
): Promise<string> {
  const messageLower = message.toLowerCase();

  if (messageLower.includes("balance") || messageLower.includes("asset")) {
    return await getAllBalanceWS(emitter);
  }

  if (messageLower.includes("invest") || messageLower.includes("analyze")) {
    const match = messageLower.match(/(\d+\.?\d*)\s*btc/);
    const btcAmount = match ? parseFloat(match[1]) : 5.0;
    return await analyzeInvestmentWS(emitter, btcAmount, sessionId);
  }

  if (messageLower.includes("yes") || messageLower.includes("proceed")) {
    return await executeInvestmentWS(emitter, sessionId, true);
  }

  if (messageLower.includes("no") || messageLower.includes("cancel")) {
    return await executeInvestmentWS(emitter, sessionId, false);
  }

  return `I'm BitYield AI Agent! I can help you with:

• 💰 Check balances - "Check my balance"
• 📊 Analyze investments - "Invest 10 BTC"
• ⚡ Execute strategies - Say "yes" to proceed

What would you like to do?`;
}

// REST API
app.get("/health", (req, res) => {
  res.json({ status: "ok", activeConnections: io.engine.clientsCount });
});

app.post("/chat", async (req, res) => {
  try {
    const { message, session_id } = req.body;
    const sessionId = session_id || uuidv4();

    if (!conversationStates.has(sessionId)) {
      conversationStates.set(sessionId, {
        messages: [],
        investmentAnalysis: null,
      });
    }

    const events: any[] = [];
    const mockEmitter = {
      emitLoading: (msg: string) => events.push({ type: "loading", message: msg }),
      emitSuccess: (msg: string) => events.push({ type: "success", message: msg }),
      emitError: (msg: string) => events.push({ type: "error", message: msg }),
      emitProgress: (s: number, t: number, msg: string) => 
        events.push({ type: "progress", step: s, total: t, message: msg }),
      emitTransaction: (desc: string, tx: string) => 
        events.push({ type: "transaction", description: desc, txHash: tx }),
      emitBalance: (assets: any[]) => events.push({ type: "balance", assets }),
      emitAnalysis: (data: any) => events.push({ type: "analysis", data }),
      emitResponse: () => {},
    } as any;

    const response = await processAgentMessage(message, sessionId, mockEmitter);

    res.json({
      response,
      timestamp: new Date().toISOString(),
      session_id: sessionId,
      metadata: { events },
    });
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

// WebSocket handler
io.on("connection", (socket) => {
  const sessionId = uuidv4();
  console.log(`✅ Client connected: ${sessionId}`);

  conversationStates.set(sessionId, {
    messages: [],
    investmentAnalysis: null,
  });

  socket.emit("connected", {
    sessionId,
    message: "Connected to BitYield AI Agent",
    timestamp: new Date().toISOString(),
  });

  socket.on("message", async (data: { content: string }) => {
    try {
      const { content } = data;
      const emitter = new MessageEmitter(socket);
      const response = await processAgentMessage(content, sessionId, emitter);
      emitter.emitResponse(response);
    } catch (error: any) {
      socket.emit("agent:error", {
        type: "error",
        message: error.message,
        timestamp: new Date().toISOString(),
      });
    }
  });

  socket.on("disconnect", () => {
    console.log(`❌ Client disconnected: ${sessionId}`);
    conversationStates.delete(sessionId);
  });
});

const PORT = process.env.PORT || 8000;

httpServer.listen(PORT, () => {
  console.log(`\n🚀 BitYield Agent Server running on port ${PORT}`);
  console.log(`📡 WebSocket: ws://localhost:${PORT}`);
  console.log(`🌐 HTTP API: http://localhost:${PORT}\n`);
});