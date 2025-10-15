// src/utils/display.mts

export function displayLoading(message: string, duration: number = 2000): void {
  const frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
  let frameIndex = 0;
  const interval = setInterval(() => {
    process.stdout.write(`\r${frames[frameIndex]} ${message}`);
    frameIndex = (frameIndex + 1) % frames.length;
  }, 80);

  return new Promise<void>((resolve) => {
    setTimeout(() => {
      clearInterval(interval);
      process.stdout.write('\r');
      resolve();
    }, duration);
  }) as any;
}

export function displaySuccess(message: string): void {
  console.log(`\n✅ ${message}\n`);
}

export function displayError(message: string): void {
  console.log(`\n❌ ${message}\n`);
}

export function displayInfo(message: string): void {
  console.log(`\nℹ️  ${message}\n`);
}

export function displayBalance(symbol: string, amount: number, chain: string): void {
  const chainStr = chain ? ` (${chain})` : '';
  console.log(`   • ${symbol}: ${amount.toFixed(4)}${chain}`);
}

export function displayTransaction(description: string, hash: string): void {
  console.log(`   📝 ${description}`);
  console.log(`      Hash: ${hash}`);
}

export function displayTable(data: Record<string, any>): void {
  console.log('\n┌─────────────────────────────────────────────┐');
  for (const [key, value] of Object.entries(data)) {
    const paddedKey = key.padEnd(25);
    console.log(`│ ${paddedKey}: ${value}`);
  }
  console.log('└─────────────────────────────────────────────┘\n');
}

export function displaySeparator(): void {
  console.log('\n─────────────────────────────────────────────\n');
}

export function displayAgentResponse(response: string): void {
  console.log('\n🤖 Agent:\n');
  console.log(response);
  console.log();
}