"use client";

import React, { useState, useEffect } from "react";
import {
  Wallet,
  TrendingUp,
  Shield,
  Zap,
  ArrowRight,
  Bitcoin,
  Boxes,
  Brain,
  ChevronDown,
  Menu,
  X,
  Github,
  Twitter,
  FileText,
} from "lucide-react";
import Image from "next/image";

export default function BitYieldLanding() {
  const [scrolled, setScrolled] = useState(false);
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [activeFeature, setActiveFeature] = useState(0);

  useEffect(() => {
    const handleScroll = () => setScrolled(window.scrollY > 50);
    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  useEffect(() => {
    const interval = setInterval(() => {
      setActiveFeature((prev) => (prev + 1) % 4);
    }, 3000);
    return () => clearInterval(interval);
  }, []);

  const features = [
    {
      icon: <Bitcoin className="w-6 h-6" />,
      title: "Bitcoin Native",
      description:
        "One-click Bitcoin deposits via Atomiq bridge - no manual wrapping required",
    },
    {
      icon: <Brain className="w-6 h-6" />,
      title: "AI-Powered Agent",
      description:
        "LangGraph AI agent automates contract interactions and optimizes your yields",
    },
    {
      icon: <TrendingUp className="w-6 h-6" />,
      title: "Auto-Optimization",
      description:
        "Automatically rebalances across Vesu lending and Troves strategies",
    },
    {
      icon: <Shield className="w-6 h-6" />,
      title: "Secure & Audited",
      description:
        "Built on Starknet with Cairo smart contracts and comprehensive testing",
    },
  ];

  const stats = [
    { label: "Total Value Locked", value: "$12.4M", suffix: "" },
    { label: "Average APY", value: "18.5", suffix: "%" },
    { label: "Active Users", value: "2,847", suffix: "" },
    { label: "Protocols Integrated", value: "3", suffix: "+" },
  ];

  const protocols = [
    { name: "Atomiq", logo: "/atomiqLogo.jpg" },
    { name: "Vesu", logo: "/vesuLogo.jpg" },
    { name: "Troves", logo: "/trovesLogo.jpg" },
    { name: "Starknet", logo: "/starknetLogo.png" },
  ];

  const howItWorks = [
    {
      step: "1",
      title: "Connect Wallet",
      description: "Connect your Xverse (Bitcoin) or Starknet wallet",
    },
    {
      step: "2",
      title: "Deposit Bitcoin",
      description: "Bridge BTC to WBTC seamlessly via Atomiq",
    },
    {
      step: "3",
      title: "AI Optimization",
      description: "Our AI agent deploys funds to highest-yield strategies",
    },
    {
      step: "4",
      title: "Earn Yields",
      description: "Watch your Bitcoin earn DeFi yields automatically",
    },
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-950 via-purple-950 to-slate-950 text-white">
      {/* Navigation */}
      <nav
        className={`fixed top-0 w-full z-50 transition-all duration-300 ${scrolled ? "bg-slate-950/95 backdrop-blur-lg border-b border-purple-500/20" : ""}`}
      >
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16 sm:h-20">
            <div className="flex items-center gap-3">
              <Image
                src="/BitYieldLogo.png"
                alt="BitYield Logo"
                width={40}
                height={40}
                className="rounded-xl"
              />
              <span className="text-xl sm:text-2xl font-bold bg-gradient-to-r from-orange-400 to-purple-400 bg-clip-text text-transparent">
                BitYield
              </span>
            </div>

            {/* Desktop Menu */}
            <div className="hidden md:flex items-center gap-8">
              <a
                href="#features"
                className="hover:text-purple-400 transition-colors"
              >
                Features
              </a>
              <a
                href="#how-it-works"
                className="hover:text-purple-400 transition-colors"
              >
                How It Works
              </a>
              <a
                href="#protocols"
                className="hover:text-purple-400 transition-colors"
              >
                Protocols
              </a>
              <a
                href="https://github.com"
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-purple-400 transition-colors"
              >
                <Github className="w-5 h-5" />
              </a>
              <button className="px-6 py-2.5 bg-gradient-to-r from-orange-500 to-purple-600 rounded-lg font-semibold hover:shadow-lg hover:shadow-purple-500/50 transition-all">
                <a href="/yield">Launch App</a>
              </button>
            </div>

            {/* Mobile Menu Button */}
            <button
              className="md:hidden p-2"
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            >
              {mobileMenuOpen ? (
                <X className="w-6 h-6" />
              ) : (
                <Menu className="w-6 h-6" />
              )}
            </button>
          </div>

          {/* Mobile Menu */}
          {mobileMenuOpen && (
            <div className="md:hidden py-4 border-t border-purple-500/20">
              <div className="flex flex-col gap-4">
                <a
                  href="#features"
                  className="hover:text-purple-400 transition-colors"
                >
                  Features
                </a>
                <a
                  href="#how-it-works"
                  className="hover:text-purple-400 transition-colors"
                >
                  How It Works
                </a>
                <a
                  href="#protocols"
                  className="hover:text-purple-400 transition-colors"
                >
                  Protocols
                </a>
                <button className="px-6 py-2.5 bg-gradient-to-r from-orange-500 to-purple-600 rounded-lg font-semibold">
                  <a href="/yield">Launch App</a>
                </button>
              </div>
            </div>
          )}
        </div>
      </nav>

      {/* Hero Section */}
      <section className="pt-32 sm:pt-40 pb-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <div className="text-center max-w-4xl mx-auto">
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-purple-500/10 border border-purple-500/30 rounded-full mb-6 sm:mb-8">
              <Zap className="w-4 h-4 text-yellow-400" />
              <span className="text-sm">Powered by AI & Starknet</span>
            </div>

            <h1 className="text-4xl sm:text-5xl md:text-7xl font-bold mb-6 sm:mb-8 leading-tight">
              <span className="bg-gradient-to-r from-orange-400 via-purple-400 to-blue-400 bg-clip-text text-transparent">
                Bitcoin-Native
              </span>
              <br />
              Yield Aggregator
            </h1>

            <p className="text-lg sm:text-xl text-slate-300 mb-8 sm:mb-12 max-w-2xl mx-auto">
              Earn DeFi yields on your Bitcoin with one click. No bridges, no
              complexity. Our AI agent optimizes your returns automatically.
            </p>

            <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
              <button className="w-full sm:w-auto px-8 py-4 bg-gradient-to-r from-orange-500 to-purple-600 rounded-xl font-semibold text-lg hover:shadow-2xl hover:shadow-purple-500/50 transition-all flex items-center justify-center gap-2 group">
                <a href="/yield" className="flex items-center gap-2">
                  Start Earning
                  <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
                </a>
              </button>
              <button className="w-full sm:w-auto px-8 py-4 border-2 border-purple-500/50 rounded-xl font-semibold text-lg hover:bg-purple-500/10 transition-all">
                View Docs
              </button>
            </div>

            {/* Stats */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-6 sm:gap-8 mt-16 sm:mt-20">
              {stats.map((stat, idx) => (
                <div key={idx} className="text-center">
                  <div className="text-2xl sm:text-3xl md:text-4xl font-bold bg-gradient-to-r from-orange-400 to-purple-400 bg-clip-text text-transparent mb-2">
                    {stat.value}
                    {stat.suffix}
                  </div>
                  <div className="text-xs sm:text-sm text-slate-400">
                    {stat.label}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4">
              Why Choose{" "}
              <span className="bg-gradient-to-r from-orange-400 to-purple-400 bg-clip-text text-transparent">
                BitYield
              </span>
            </h2>
            <p className="text-slate-300 text-lg">
              The most advanced Bitcoin yield platform on Starknet
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
            {features.map((feature, idx) => (
              <div
                key={idx}
                className={`p-6 rounded-2xl border transition-all duration-300 cursor-pointer ${
                  activeFeature === idx
                    ? "bg-gradient-to-br from-purple-500/20 to-orange-500/20 border-purple-500/50 shadow-xl shadow-purple-500/20"
                    : "bg-slate-900/50 border-slate-800 hover:border-purple-500/30"
                }`}
                onMouseEnter={() => setActiveFeature(idx)}
              >
                <div
                  className={`w-12 h-12 rounded-xl flex items-center justify-center mb-4 ${
                    activeFeature === idx
                      ? "bg-gradient-to-br from-orange-500 to-purple-600"
                      : "bg-slate-800"
                  }`}
                >
                  {feature.icon}
                </div>
                <h3 className="text-xl font-semibold mb-2">{feature.title}</h3>
                <p className="text-slate-400">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* How It Works */}
      <section
        id="how-it-works"
        className="py-20 px-4 sm:px-6 lg:px-8 bg-slate-900/30"
      >
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4">
              How It Works
            </h2>
            <p className="text-slate-300 text-lg">
              Four simple steps to start earning
            </p>
          </div>

          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-8">
            {howItWorks.map((item, idx) => (
              <div key={idx} className="relative">
                <div className="bg-gradient-to-br from-slate-900 to-slate-800 p-6 rounded-2xl border border-slate-700 hover:border-purple-500/50 transition-all">
                  <div className="w-12 h-12 bg-gradient-to-br from-orange-500 to-purple-600 rounded-xl flex items-center justify-center text-2xl font-bold mb-4">
                    {item.step}
                  </div>
                  <h3 className="text-xl font-semibold mb-2">{item.title}</h3>
                  <p className="text-slate-400">{item.description}</p>
                </div>
                {idx < howItWorks.length - 1 && (
                  <div className="hidden lg:block absolute top-1/2 -right-4 w-8 h-0.5 bg-gradient-to-r from-purple-500 to-transparent"></div>
                )}
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Protocols Integration */}
      <section id="protocols" className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-7xl mx-auto">
          <div className="text-center mb-16">
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-4">
              Integrated Protocols
            </h2>
            <p className="text-slate-300 text-lg">
              Built on the best DeFi infrastructure
            </p>
          </div>

          <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
            {protocols.map((protocol, idx) => (
              <div
                key={idx}
                className="bg-slate-900/50 border border-slate-800 rounded-2xl p-8 hover:border-purple-500/50 transition-all flex flex-col items-center justify-center gap-4"
              >
                <div>
                  <Image
                    src={protocol.logo}
                    alt={`${protocol.name} Logo`}
                    width={70}
                    height={70}
                    className="rounded-xl"
                  />
                </div>
                <div className="text-xl font-semibold">{protocol.name}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto">
          <div className="bg-gradient-to-br from-orange-500/10 via-purple-500/10 to-blue-500/10 border border-purple-500/30 rounded-3xl p-8 sm:p-12 text-center">
            <h2 className="text-3xl sm:text-4xl md:text-5xl font-bold mb-6">
              Ready to Earn Yields on Your Bitcoin?
            </h2>
            <p className="text-slate-300 text-lg mb-8 max-w-2xl mx-auto">
              Join thousands of Bitcoin holders earning passive DeFi yields with
              AI-powered optimization
            </p>
            <button className="px-8 py-4 bg-gradient-to-r from-orange-500 to-purple-600 rounded-xl font-semibold text-lg hover:shadow-2xl hover:shadow-purple-500/50 transition-all inline-flex items-center gap-2 group">
              <a href="/yield" className="flex items-center gap-2">
                Launch App Now
                <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
              </a>
            </button>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-12 px-4 sm:px-6 lg:px-8 border-t border-slate-800">
        <div className="max-w-7xl mx-auto">
          <div className="grid md:grid-cols-4 gap-8 mb-8">
            <div>
              <div className="flex items-center gap-3 mb-4">
                <Image
                  src="/BitYieldLogo.png"
                  alt="BitYield Logo"
                  width={40}
                  height={40}
                  className="rounded-xl"
                />
                <span className="text-xl font-bold">BitYield</span>
              </div>
              <p className="text-slate-400 text-sm">
                Bitcoin-native yield aggregator powered by AI on Starknet
              </p>
            </div>

            <div>
              <h4 className="font-semibold mb-4">Product</h4>
              <div className="flex flex-col gap-2 text-sm text-slate-400">
                <a href="#" className="hover:text-purple-400 transition-colors">
                  Features
                </a>
                <a href="#" className="hover:text-purple-400 transition-colors">
                  How It Works
                </a>
                <a href="#" className="hover:text-purple-400 transition-colors">
                  Security
                </a>
              </div>
            </div>

            <div>
              <h4 className="font-semibold mb-4">Resources</h4>
              <div className="flex flex-col gap-2 text-sm text-slate-400">
                <a href="#" className="hover:text-purple-400 transition-colors">
                  Documentation
                </a>
                <a href="#" className="hover:text-purple-400 transition-colors">
                  GitHub
                </a>
                <a href="#" className="hover:text-purple-400 transition-colors">
                  Audit Reports
                </a>
              </div>
            </div>

            <div>
              <h4 className="font-semibold mb-4">Community</h4>
              <div className="flex gap-4">
                <a
                  href="#"
                  className="w-10 h-10 bg-slate-800 rounded-lg flex items-center justify-center hover:bg-purple-500/20 transition-colors"
                >
                  <Twitter className="w-5 h-5" />
                </a>
                <a
                  href="#"
                  className="w-10 h-10 bg-slate-800 rounded-lg flex items-center justify-center hover:bg-purple-500/20 transition-colors"
                >
                  <Github className="w-5 h-5" />
                </a>
                <a
                  href="#"
                  className="w-10 h-10 bg-slate-800 rounded-lg flex items-center justify-center hover:bg-purple-500/20 transition-colors"
                >
                  <FileText className="w-5 h-5" />
                </a>
              </div>
            </div>
          </div>

          <div className="pt-8 border-t border-slate-800 flex flex-col sm:flex-row justify-between items-center gap-4 text-sm text-slate-400">
            <p>
              © 2025 BitYield Protocol. Built for Starknet Res{"{solve}"}{" "}
              Hackathon.
            </p>
            <div className="flex gap-6">
              <a href="#" className="hover:text-purple-400 transition-colors">
                Privacy Policy
              </a>
              <a href="#" className="hover:text-purple-400 transition-colors">
                Terms of Service
              </a>
            </div>
          </div>
        </div>
      </footer>
    </div>
  );
}
