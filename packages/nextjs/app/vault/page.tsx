"use client";

import React, { useState, useEffect } from 'react';
import { TrendingUp, Shield, Zap, ArrowUpRight, ArrowDownRight, Activity, Wallet, Info, ExternalLink } from 'lucide-react';
import { Header } from '~~/components/Header';

// Mock data - replace with real data from hooks
const VAULT_DATA = {
  tvl: 5400000,
  yourHoldings: 0,
  apy: 7.5,
  strategies: [
    {
      id: 1,
      name: 'WBTC Evergreen',
      protocol: 'BitYield',
      icon: '₿',
      apy: 7.5,
      risk: 'low',
      tvl: 5400000,
      allocation: 100,
      verified: true,
      description: 'Optimized WBTC yield across Vesu lending and Troves staking'
    }
  ],
  allocations: [
    { name: 'Vesu Lending', percentage: 30, apy: 5.3, amount: 3720000 },
    { name: 'Troves Staking', percentage: 70, apy: 8.8, amount: 8680000 }
  ]
};

const getRiskColor = (risk: string) => {
  switch (risk) {
    case 'low': return 'text-green-400';
    case 'medium': return 'text-yellow-400';
    case 'high': return 'text-red-400';
    default: return 'text-gray-400';
  }
};

const getRiskBars = (risk: string) => {
  const bars = risk === 'low' ? 1 : risk === 'medium' ? 2 : 3;
  return (
    <div className="flex gap-1">
      {[1, 2, 3].map((i) => (
        <div
          key={i}
          className={`w-1 h-4 rounded ${i <= bars ? getRiskColor(risk) : 'bg-slate-700'}`}
        />
      ))}
    </div>
  );
};

export default function VaultDashboard() {
  const [activeTab, setActiveTab] = useState<'all' | 'your-positions'>('all');

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-950 via-purple-950 to-slate-950 text-white">
      {/* Header */}
      <Header />
      {/* Main Content */}
      <main className="max-w-7xl mt-24 mx-auto px-6 py-8">
        {/* Title Section */}
        <div className="mb-8">
          <h1 className="text-4xl font-bold mb-3 flex items-center gap-3">
            Bitcoin Yield Vault
            <span className="text-2xl">🚀</span>
          </h1>
          <p className="text-slate-400 text-lg">
            Discover and invest in optimized Bitcoin yield strategies.
          </p>
        </div>

        {/* Stats Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          {/* TVL Card */}
          <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 hover:border-purple-500/50 transition-all">
            <div className="text-slate-400 text-sm mb-2">Total Value Locked (TVL)</div>
            <div className="text-3xl font-bold mb-1">
              ${(VAULT_DATA.tvl / 1000000).toFixed(2)}m
            </div>
            <div className="flex items-center gap-1 text-green-400 text-sm">
              <ArrowUpRight className="w-4 h-4" />
              <span>+5.5% this month</span>
            </div>
          </div>

          {/* Holdings Card */}
          <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 hover:border-purple-500/50 transition-all">
            <div className="text-slate-400 text-sm mb-2">Your holdings</div>
            <div className="text-3xl font-bold mb-1">
              ${VAULT_DATA.yourHoldings}
            </div>
            <div className="text-slate-500 text-sm">
              Connect wallet to view
            </div>
          </div>

          {/* APY Card */}
          <div className="bg-slate-900/50 border border-slate-800 rounded-2xl p-6 hover:border-purple-500/50 transition-all">
            <div className="text-slate-400 text-sm mb-2">Average APY</div>
            <div className="text-3xl font-bold mb-1 text-purple-400">
              {VAULT_DATA.apy}%
            </div>
            <div className="flex items-center gap-1 text-purple-400 text-sm">
              <Activity className="w-4 h-4" />
              <span>Weighted average</span>
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div className="flex items-center gap-4 mb-6 border-b border-slate-800">
          <button
            onClick={() => setActiveTab('all')}
            className={`px-4 py-3 font-semibold transition-all relative ${
              activeTab === 'all'
                ? 'text-purple-400'
                : 'text-slate-400 hover:text-slate-300'
            }`}
          >
            <span className="flex items-center gap-2">
              ✨ All Strategies
            </span>
            {activeTab === 'all' && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-gradient-to-r from-orange-500 to-purple-500" />
            )}
          </button>

          <button
            onClick={() => setActiveTab('your-positions')}
            className={`px-4 py-3 font-semibold transition-all relative ${
              activeTab === 'your-positions'
                ? 'text-purple-400'
                : 'text-slate-400 hover:text-slate-300'
            }`}
          >
            Your Positions
            {activeTab === 'your-positions' && (
              <div className="absolute bottom-0 left-0 right-0 h-0.5 bg-gradient-to-r from-orange-500 to-purple-500" />
            )}
          </button>
        </div>

        {/* Info Banner */}
        <div className="mb-6 bg-purple-500/10 border border-purple-500/30 rounded-xl p-4 flex items-start gap-3">
          <Info className="w-5 h-5 text-purple-400 flex-shrink-0 mt-0.5" />
          <div className="text-sm">
            <span className="text-purple-300 font-semibold">What are BitYield Strategies?</span>
            <p className="text-slate-300 mt-1">
              Automated yield optimization strategies that allocate your Bitcoin across multiple DeFi protocols 
              to maximize returns while managing risk.
            </p>
          </div>
        </div>

        {/* Strategies Table */}
        <div className="bg-slate-900/30 border border-slate-800 rounded-2xl overflow-hidden">
          {/* Table Header */}
          <div className="grid grid-cols-12 gap-4 px-6 py-4 border-b border-slate-800 bg-purple-900/20 text-sm font-semibold text-slate-300">
            <div className="col-span-4">STRATEGY NAME</div>
            <div className="col-span-2 text-center">APY</div>
            <div className="col-span-2 text-center">RISK</div>
            <div className="col-span-2 text-right">TVL</div>
            <div className="col-span-2"></div>
          </div>

          {/* Strategy Rows */}
          {VAULT_DATA.strategies.map((strategy) => (
            <div
              key={strategy.id}
              className="grid grid-cols-12 gap-4 px-6 py-5 border-b border-slate-800/50 hover:bg-slate-800/30 transition-all group"
            >
              {/* Strategy Name */}
              <div className="col-span-4 flex items-center gap-3">
                <div className="w-10 h-10 bg-gradient-to-br from-orange-500 to-purple-600 rounded-lg flex items-center justify-center text-xl">
                  {strategy.icon}
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-semibold">{strategy.name}</span>
                    {strategy.verified && (
                      <span className="text-green-400">✓</span>
                    )}
                  </div>
                  <div className="text-sm text-slate-400 flex items-center gap-1">
                    ✨ {strategy.protocol}
                  </div>
                </div>
              </div>

              {/* APY */}
              <div className="col-span-2 flex items-center justify-center">
                <span className="text-purple-400 font-bold text-lg">
                  {strategy.apy}%
                </span>
              </div>

              {/* Risk */}
              <div className="col-span-2 flex items-center justify-center">
                {getRiskBars(strategy.risk)}
              </div>

              {/* TVL */}
              <div className="col-span-2 flex items-center justify-end">
                <span className="font-semibold">
                  ${(strategy.tvl / 1000000).toFixed(2)}m
                </span>
              </div>

              {/* Actions */}
              <div className="col-span-2 flex items-center justify-end gap-2">
                <button className="px-4 py-2 bg-purple-600 hover:bg-purple-500 rounded-lg font-semibold transition-all opacity-0 group-hover:opacity-100">
                  Deposit
                </button>
                <button className="p-2 hover:bg-slate-800 rounded-lg transition-all">
                  <ExternalLink className="w-4 h-4" />
                </button>
              </div>
            </div>
          ))}
        </div>

        {/* Strategy Breakdown */}
        <div className="mt-8 bg-slate-900/30 border border-slate-800 rounded-2xl p-6">
          <h3 className="text-xl font-bold mb-4 flex items-center gap-2">
            <Shield className="w-5 h-5 text-purple-400" />
            Strategy Breakdown
          </h3>
          
          <div className="grid md:grid-cols-2 gap-6">
            {VAULT_DATA.allocations.map((allocation, idx) => (
              <div key={idx} className="bg-slate-800/30 border border-slate-700 rounded-xl p-5">
                <div className="flex justify-between items-start mb-3">
                  <div>
                    <div className="font-semibold text-lg">{allocation.name}</div>
                    <div className="text-slate-400 text-sm">
                      ${(allocation.amount / 1000000).toFixed(2)}m allocated
                    </div>
                  </div>
                  <div className="text-purple-400 font-bold text-xl">
                    {allocation.apy}%
                  </div>
                </div>
                
                {/* Progress Bar */}
                <div className="mb-2">
                  <div className="flex justify-between text-sm text-slate-400 mb-1">
                    <span>Allocation</span>
                    <span>{allocation.percentage}%</span>
                  </div>
                  <div className="h-2 bg-slate-700 rounded-full overflow-hidden">
                    <div
                      className="h-full bg-gradient-to-r from-orange-500 to-purple-600 rounded-full transition-all"
                      style={{ width: `${allocation.percentage}%` }}
                    />
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Features Grid */}
        <div className="mt-8 grid md:grid-cols-3 gap-6">
          <div className="bg-slate-900/30 border border-slate-800 rounded-xl p-6">
            <div className="w-12 h-12 bg-green-500/20 rounded-lg flex items-center justify-center mb-4">
              <Shield className="w-6 h-6 text-green-400" />
            </div>
            <h4 className="font-semibold text-lg mb-2">Secure & Audited</h4>
            <p className="text-slate-400 text-sm">
              Smart contracts audited by leading security firms. Your funds are protected.
            </p>
          </div>

          <div className="bg-slate-900/30 border border-slate-800 rounded-xl p-6">
            <div className="w-12 h-12 bg-purple-500/20 rounded-lg flex items-center justify-center mb-4">
              <Zap className="w-6 h-6 text-purple-400" />
            </div>
            <h4 className="font-semibold text-lg mb-2">Auto-Optimization</h4>
            <p className="text-slate-400 text-sm">
              AI-powered rebalancing ensures optimal allocation across strategies.
            </p>
          </div>

          <div className="bg-slate-900/30 border border-slate-800 rounded-xl p-6">
            <div className="w-12 h-12 bg-orange-500/20 rounded-lg flex items-center justify-center mb-4">
              <TrendingUp className="w-6 h-6 text-orange-400" />
            </div>
            <h4 className="font-semibold text-lg mb-2">Maximized Yields</h4>
            <p className="text-slate-400 text-sm">
              Access institutional-grade yield strategies previously unavailable to retail.
            </p>
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-slate-800/50 mt-16">
        <div className="max-w-7xl mx-auto px-6 py-8">
          <div className="flex flex-col md:flex-row justify-between items-center gap-4">
            <div className="text-sm text-slate-400">
              © 2025 BitYield Protocol. Built for Starknet Resolve Hackathon.
            </div>
            <div className="flex gap-6 text-sm">
              <a href="#" className="text-slate-400 hover:text-purple-400 transition-colors">
                Documentation
              </a>
              <a href="https://github.com/CodeBlocker52/BitYield-Protocol" className="text-slate-400 hover:text-purple-400 transition-colors">
                GitHub
              </a>
              <a href="#" className="text-slate-400 hover:text-purple-400 transition-colors">
                Discord
              </a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}