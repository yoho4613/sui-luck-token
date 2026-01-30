# Lucky Day SUI Smart Contracts

SUI Move smart contracts for the Lucky Day Play-to-Earn gaming platform.

## Devnet Deployment (Live)

| Object | ID |
|--------|-----|
| **Package** | `0x5cbe88ff66b4772358bcda0e509b955d3c51d05f956343253f8d780a5361c661` |
| **TreasuryCap** | `0x42f63b010b2a3e68ceb4140b0946022b57cbb5f5b8320ae652c759b1c1e03993` |
| **CoinMetadata** | `0xce7b639220988dd4949d73878eb1de92eb9a1e8cfeb20db4097bcb27835b7535` |
| **RewardPool** | `0x7ea5d43e816547f5958af82299e4b7ccf247f4f6e35b9e616d7cfb1c528a985d` |

> **Note:** Contracts updated with Pause/MaxSupply features. Redeploy required to use new features.

**Explorer Links:**
- [Package](https://suiscan.xyz/devnet/object/0x5cbe88ff66b4772358bcda0e509b955d3c51d05f956343253f8d780a5361c661)
- [TreasuryCap](https://suiscan.xyz/devnet/object/0x42f63b010b2a3e68ceb4140b0946022b57cbb5f5b8320ae652c759b1c1e03993)
- [RewardPool](https://suiscan.xyz/devnet/object/0x7ea5d43e816547f5958af82299e4b7ccf247f4f6e35b9e616d7cfb1c528a985d)

## Contracts

### 1. LUCK Token (`luck_token.move`)

Standard SUI fungible token (Coin) for the Lucky Day ecosystem.

| Property | Value |
|----------|-------|
| **Symbol** | LUCK |
| **Name** | Lucky Token |
| **Decimals** | 9 |
| **Max Supply** | 1,000,000,000 (hard cap enforced) |

**Core Functions:**
- `mint()` - Mint tokens to a recipient (TreasuryCap holder only)
- `burn()` - Burn tokens from a coin object
- `mint_batch()` - Batch mint to multiple recipients (airdrops, leaderboard payouts)
- `total_supply()` - Get current total supply
- `remaining_supply()` - Get remaining mintable tokens

**Admin Functions:**
- `pause()` - Emergency pause all minting operations
- `unpause()` - Resume minting operations
- `transfer_admin()` - Transfer admin role to new address

**View Functions:**
- `max_supply()` - Get maximum supply cap (1B LUCK)
- `is_paused()` - Check if minting is paused
- `config_admin()` - Get current admin address

**Events:**
- `TokenPaused` - Minting paused
- `TokenUnpaused` - Minting resumed
- `AdminTransferred` - Admin role transferred

### 2. Reward Pool (`reward_pool.move`)

Shared object holding SUI for prize distribution to game winners.

**Features:**
- `create_pool()` - Create the shared reward pool
- `deposit()` - Admin deposits SUI into the pool
- `distribute_reward()` - Send SUI reward to a single winner
- `distribute_batch()` - Batch distribute to multiple winners (leaderboard)
- `transfer_admin()` - Transfer admin role
- `withdraw()` - Emergency withdrawal

**Events:**
- `PoolCreated` - Pool initialization
- `Deposited` - SUI deposited to pool
- `RewardDistributed` - Single reward sent
- `BatchDistributed` - Batch rewards sent
- `AdminTransferred` - Admin changed

### 3. Vesting (`vesting.move`)

Time-locked token distribution for investors and team.

**Features:**
- `create_registry()` - Create vesting registry (admin)
- `create_schedule()` - Create vesting schedule for beneficiary
- `release()` - Release vested tokens to beneficiary
- `revoke()` - Revoke unvested tokens (admin, only if revocable)

**Vesting Parameters:**
- **Cliff Period**: No tokens released until cliff ends
- **Linear Vesting**: Tokens released gradually after cliff
- **Revocable Option**: Admin can revoke unvested tokens (for employees)

**Example Schedules:**
| Type | Cliff | Vesting | Revocable |
|------|-------|---------|-----------|
| VC/Investor | 12 months | 24 months | No |
| Team | 12 months | 36 months | Yes |
| Advisor | 6 months | 12 months | Yes |

## Test

```bash
sui move test -e testnet
```

All 31 tests should pass:
- 11 tests for `luck_token`
- 11 tests for `reward_pool`
- 9 tests for `vesting`

## Deploy to Devnet

```bash
# Switch to devnet
sui client switch --env devnet

# Get devnet SUI
sui client faucet

# Deploy
sui client test-publish --gas-budget 100000000 --build-env devnet
```

## Usage Examples

### Mint LUCK Tokens

```bash
# Note: After update, mint requires TokenConfig object
sui client call \
  --package <PACKAGE_ID> \
  --module luck_token \
  --function mint \
  --args <TOKEN_CONFIG_ID> <TREASURY_CAP_ID> 1000000000000 <RECIPIENT_ADDRESS> \
  --gas-budget 10000000
```

### Pause/Unpause Minting

```bash
# Pause (emergency)
sui client call \
  --package <PACKAGE_ID> \
  --module luck_token \
  --function pause \
  --args <TOKEN_CONFIG_ID> \
  --gas-budget 10000000

# Unpause
sui client call \
  --package <PACKAGE_ID> \
  --module luck_token \
  --function unpause \
  --args <TOKEN_CONFIG_ID> \
  --gas-budget 10000000
```

### Create Reward Pool

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module reward_pool \
  --function create_pool \
  --gas-budget 10000000
```

### Create Vesting Schedule

```bash
# First create registry
sui client call \
  --package <PACKAGE_ID> \
  --module vesting \
  --function create_registry \
  --gas-budget 10000000

# Then create schedule (12 month cliff + 24 month vesting)
sui client call \
  --package <PACKAGE_ID> \
  --module vesting \
  --function create_schedule \
  --args <REGISTRY_ID> <LUCK_COIN_ID> <BENEFICIARY> <START_TIME_MS> 31536000000 63072000000 false \
  --gas-budget 10000000
```

## Project Structure

```
contract/
├── Move.toml
├── sources/
│   ├── luck_token.move    # LUCK token contract
│   ├── reward_pool.move   # SUI reward distribution
│   └── vesting.move       # Token vesting for VC/Team
├── tests/
│   ├── luck_token_tests.move
│   ├── reward_pool_tests.move
│   └── vesting_tests.move
└── examples/
    └── sdk-usage.ts       # TypeScript SDK examples
```

## Security Features

### Current Security

| Feature | Status | Description |
|---------|--------|-------------|
| **Max Supply Cap** | ✅ Enforced | 1B LUCK hard cap in contract |
| **Pause Mechanism** | ✅ Implemented | Emergency stop for minting |
| **Admin Transfer** | ✅ Implemented | Secure admin role handoff |
| **TreasuryCap Protection** | ✅ Native | Only holder can mint |
| **Metadata Frozen** | ✅ Immutable | Cannot change token info |

### Mainnet Checklist

Before mainnet deployment:

- [ ] **Security Audit** - Professional code review (OtterSec, MoveBit)
- [ ] **Multi-sig Setup** - Configure 2-of-3 or 3-of-5 admin wallet
- [ ] **TreasuryCap Storage** - Hardware wallet recommended
- [ ] **Testnet Verification** - Full testing on testnet
- [ ] **Admin Key Backup** - Secure backup procedures

## Multi-sig Roadmap

SUI natively supports multi-signature accounts. Our contracts are **already compatible** with multi-sig.

### Recommended Configuration by Stage

| Stage | Config | Signers | Description |
|-------|--------|---------|-------------|
| **Development** | 1/1 | Founder | Fast iteration |
| **Beta** | 2/2 | Co-founders | Basic security |
| **Mainnet Launch** | 2/3 | Team + Advisor | Production security |
| **Growth** | 3/5 | Team + Community | Decentralization |

### How to Apply Multi-sig

```typescript
import { MultiSigPublicKey } from '@mysten/sui/multisig';

// Create 2-of-3 multi-sig
const multiSigPublicKey = MultiSigPublicKey.fromPublicKeys({
  threshold: 2,
  publicKeys: [
    { publicKey: ceoKey, weight: 1 },
    { publicKey: ctoKey, weight: 1 },
    { publicKey: advisorKey, weight: 1 },
  ],
});

const multiSigAddress = multiSigPublicKey.toSuiAddress();

// Transfer admin to multi-sig address
// luck_token::transfer_admin(&mut config, multiSigAddress, ctx);
// reward_pool::transfer_admin(&mut pool, multiSigAddress, ctx);
```

### Multi-sig Benefits

| Risk | Single-sig | Multi-sig (2/3) |
|------|------------|-----------------|
| Key compromised | All access lost | 1 key = no access |
| Admin mistake | Immediate execution | Others can reject |
| Admin leaves | Project blocked | 2 others continue |
| Insider threat | Solo execution | Requires collusion |

## Security Considerations

1. **TreasuryCap Protection**: Store securely (hardware wallet for mainnet)
2. **Admin Key Security**: RewardPool/Vesting admin controls distributions
3. **Vesting Revocability**: VC schedules should be non-revocable
4. **Gradual Deposits**: Start small, increase gradually
5. **Metadata Frozen**: CoinMetadata is immutable after init
6. **Pause for Emergencies**: Use pause() if exploit discovered
7. **Max Supply Enforced**: Cannot mint beyond 1B LUCK ever

## License

MIT

## Links

- [Lucky Day App](https://yourluckyday.app)
- [SUI Documentation](https://docs.sui.io)
- [Move Language](https://move-language.github.io/move/)
- [SUI Multi-sig Guide](https://docs.sui.io/concepts/cryptography/transaction-auth/multisig)
