/**
 * Lucky Day SUI SDK Usage Examples
 *
 * Prerequisites:
 * - npm install @mysten/sui
 * - Set ADMIN_PRIVATE_KEY environment variable
 */

import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { fromB64 } from '@mysten/sui/utils';

// ============================================
// Configuration (Devnet)
// ============================================

const PACKAGE_ID = '0x5cbe88ff66b4772358bcda0e509b955d3c51d05f956343253f8d780a5361c661';
const TREASURY_CAP_ID = '0x42f63b010b2a3e68ceb4140b0946022b57cbb5f5b8320ae652c759b1c1e03993';
const REWARD_POOL_ID = '0x7ea5d43e816547f5958af82299e4b7ccf247f4f6e35b9e616d7cfb1c528a985d';
const COIN_TYPE = `${PACKAGE_ID}::luck_token::LUCK_TOKEN`;

// Initialize client
const client = new SuiClient({ url: getFullnodeUrl('devnet') });

// Initialize keypair from private key (base64)
function getKeypair(): Ed25519Keypair {
  const privateKey = process.env.ADMIN_PRIVATE_KEY;
  if (!privateKey) throw new Error('ADMIN_PRIVATE_KEY not set');
  return Ed25519Keypair.fromSecretKey(fromB64(privateKey));
}

// ============================================
// 1. Mint LUCK Tokens
// ============================================

export async function mintLuckTokens(
  recipientAddress: string,
  amount: bigint // in base units (with decimals)
): Promise<string> {
  const keypair = getKeypair();

  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::luck_token::mint`,
    arguments: [
      tx.object(TREASURY_CAP_ID),
      tx.pure.u64(amount),
      tx.pure.address(recipientAddress),
    ],
  });

  const result = await client.signAndExecuteTransaction({
    signer: keypair,
    transaction: tx,
  });

  console.log('Mint TX:', result.digest);
  return result.digest;
}

// ============================================
// 2. Batch Mint (Airdrop)
// ============================================

export async function batchMintLuckTokens(
  recipients: { address: string; amount: bigint }[]
): Promise<string> {
  const keypair = getKeypair();

  const tx = new Transaction();

  const amounts = recipients.map(r => r.amount);
  const addresses = recipients.map(r => r.address);

  tx.moveCall({
    target: `${PACKAGE_ID}::luck_token::mint_batch`,
    arguments: [
      tx.object(TREASURY_CAP_ID),
      tx.pure.vector('u64', amounts),
      tx.pure.vector('address', addresses),
    ],
  });

  const result = await client.signAndExecuteTransaction({
    signer: keypair,
    transaction: tx,
  });

  console.log('Batch Mint TX:', result.digest);
  return result.digest;
}

// ============================================
// 3. Deposit SUI to Reward Pool
// ============================================

export async function depositToRewardPool(
  suiCoinId: string
): Promise<string> {
  const keypair = getKeypair();

  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::reward_pool::deposit`,
    arguments: [
      tx.object(REWARD_POOL_ID),
      tx.object(suiCoinId),
    ],
  });

  const result = await client.signAndExecuteTransaction({
    signer: keypair,
    transaction: tx,
  });

  console.log('Deposit TX:', result.digest);
  return result.digest;
}

// ============================================
// 4. Distribute SUI Reward
// ============================================

export async function distributeReward(
  winnerAddress: string,
  amount: bigint // in MIST
): Promise<string> {
  const keypair = getKeypair();

  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::reward_pool::distribute_reward`,
    arguments: [
      tx.object(REWARD_POOL_ID),
      tx.pure.u64(amount),
      tx.pure.address(winnerAddress),
    ],
  });

  const result = await client.signAndExecuteTransaction({
    signer: keypair,
    transaction: tx,
  });

  console.log('Distribute TX:', result.digest);
  return result.digest;
}

// ============================================
// 5. Batch Distribute (Leaderboard)
// ============================================

export async function distributeLeaderboardRewards(
  winners: { address: string; amount: bigint }[]
): Promise<string> {
  const keypair = getKeypair();

  const tx = new Transaction();

  const amounts = winners.map(w => w.amount);
  const addresses = winners.map(w => w.address);

  tx.moveCall({
    target: `${PACKAGE_ID}::reward_pool::distribute_batch`,
    arguments: [
      tx.object(REWARD_POOL_ID),
      tx.pure.vector('u64', amounts),
      tx.pure.vector('address', addresses),
    ],
  });

  const result = await client.signAndExecuteTransaction({
    signer: keypair,
    transaction: tx,
  });

  console.log('Batch Distribute TX:', result.digest);
  return result.digest;
}

// ============================================
// 6. Query Functions
// ============================================

export async function getRewardPoolBalance(): Promise<bigint> {
  const pool = await client.getObject({
    id: REWARD_POOL_ID,
    options: { showContent: true },
  });

  if (pool.data?.content?.dataType === 'moveObject') {
    const fields = pool.data.content.fields as any;
    return BigInt(fields.balance);
  }

  throw new Error('Failed to fetch pool balance');
}

export async function getTotalLuckSupply(): Promise<bigint> {
  const treasury = await client.getObject({
    id: TREASURY_CAP_ID,
    options: { showContent: true },
  });

  if (treasury.data?.content?.dataType === 'moveObject') {
    const fields = treasury.data.content.fields as any;
    return BigInt(fields.total_supply?.fields?.value || 0);
  }

  throw new Error('Failed to fetch total supply');
}

export async function getUserLuckBalance(address: string): Promise<bigint> {
  const coins = await client.getCoins({
    owner: address,
    coinType: COIN_TYPE,
  });

  let total = 0n;
  for (const coin of coins.data) {
    total += BigInt(coin.balance);
  }

  return total;
}

// ============================================
// 7. Vesting Functions
// ============================================

export async function createVestingRegistry(): Promise<string> {
  const keypair = getKeypair();

  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::vesting::create_registry`,
  });

  const result = await client.signAndExecuteTransaction({
    signer: keypair,
    transaction: tx,
  });

  console.log('Create Registry TX:', result.digest);
  return result.digest;
}

export async function createVestingSchedule(
  registryId: string,
  luckCoinId: string,
  beneficiary: string,
  startTimeMs: bigint,
  cliffDurationMs: bigint,
  vestingDurationMs: bigint,
  revocable: boolean
): Promise<string> {
  const keypair = getKeypair();

  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::vesting::create_schedule`,
    arguments: [
      tx.object(registryId),
      tx.object(luckCoinId),
      tx.pure.address(beneficiary),
      tx.pure.u64(startTimeMs),
      tx.pure.u64(cliffDurationMs),
      tx.pure.u64(vestingDurationMs),
      tx.pure.bool(revocable),
    ],
  });

  const result = await client.signAndExecuteTransaction({
    signer: keypair,
    transaction: tx,
  });

  console.log('Create Schedule TX:', result.digest);
  return result.digest;
}

// ============================================
// Usage Examples
// ============================================

async function main() {
  // Example: Mint 1000 LUCK tokens
  // await mintLuckTokens('0x...recipient', 1000_000_000_000n);

  // Example: Airdrop to multiple addresses
  // await batchMintLuckTokens([
  //   { address: '0x...', amount: 100_000_000_000n },
  //   { address: '0x...', amount: 200_000_000_000n },
  // ]);

  // Example: Distribute leaderboard rewards
  // await distributeLeaderboardRewards([
  //   { address: '0x...winner1', amount: 1_000_000_000n }, // 1 SUI
  //   { address: '0x...winner2', amount: 500_000_000n },   // 0.5 SUI
  //   { address: '0x...winner3', amount: 250_000_000n },   // 0.25 SUI
  // ]);

  // Query examples
  const poolBalance = await getRewardPoolBalance();
  console.log('Reward Pool Balance:', poolBalance, 'MIST');

  const totalSupply = await getTotalLuckSupply();
  console.log('Total LUCK Supply:', totalSupply);
}

main().catch(console.error);
