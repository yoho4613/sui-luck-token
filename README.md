# Lucky Day SUI Smart Contracts

SUI Move smart contracts for the Lucky Day Play-to-Earn gaming platform.

## Contracts

### 1. LUCK Token (`luck_token.move`)

Standard SUI fungible token (Coin) for the Lucky Day ecosystem.

| Property | Value |
|----------|-------|
| **Symbol** | LUCK |
| **Name** | Lucky Token |
| **Decimals** | 9 |
| **Max Supply** | 1,000,000,000 (minted on demand) |

**Features:**
- `mint()` - Mint tokens to a recipient (TreasuryCap holder only)
- `burn()` - Burn tokens from a coin object
- `mint_batch()` - Batch mint to multiple recipients (airdrops, leaderboard payouts)
- `total_supply()` - Get current total supply

**Token Distribution Plan:**
- Airdrop: 5% (50M LUCK)
- Liquidity Pool: 30% (300M LUCK)
- Play-to-Earn Rewards: 20% (200M LUCK)
- Team/Development: 15% (150M LUCK)
- Marketing: 10% (100M LUCK)
- Reserve: 20% (200M LUCK)

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

## Prerequisites

- [SUI CLI](https://docs.sui.io/guides/developer/getting-started/sui-install) installed
- SUI wallet with testnet/devnet SUI

## Build

```bash
sui move build
```

## Test

```bash
sui move test
```

All 16 tests should pass:
- 5 tests for `luck_token`
- 11 tests for `reward_pool`

## Deploy to Devnet

```bash
# Switch to devnet
sui client switch --env devnet

# Get devnet SUI
sui client faucet

# Deploy
sui client publish --gas-budget 100000000
```

After deployment, save these object IDs:
- **Package ID**: The published package address
- **TreasuryCap ID**: For minting LUCK tokens
- **CoinMetadata ID**: Token metadata (frozen)

## Deploy Reward Pool

After publishing the package, create the reward pool:

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module reward_pool \
  --function create_pool \
  --gas-budget 10000000
```

Save the **RewardPool ID** from the created shared object.

## Usage Examples

### Mint LUCK Tokens

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module luck_token \
  --function mint \
  --args <TREASURY_CAP_ID> 1000000000 <RECIPIENT_ADDRESS> \
  --gas-budget 10000000
```

### Deposit SUI to Reward Pool

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module reward_pool \
  --function deposit \
  --args <REWARD_POOL_ID> <SUI_COIN_ID> \
  --gas-budget 10000000
```

### Distribute Reward

```bash
sui client call \
  --package <PACKAGE_ID> \
  --module reward_pool \
  --function distribute_reward \
  --args <REWARD_POOL_ID> 100000000 <WINNER_ADDRESS> \
  --gas-budget 10000000
```

## Security Considerations

1. **TreasuryCap Protection**: The TreasuryCap should be stored securely (hardware wallet recommended for mainnet)
2. **Admin Key Security**: RewardPool admin address controls all distributions
3. **Gradual Deposits**: Start with small amounts in RewardPool, increase gradually
4. **Metadata Frozen**: CoinMetadata is frozen at init, cannot be modified

## Project Structure

```
contract/
├── Move.toml           # Package manifest
├── sources/
│   ├── luck_token.move    # LUCK token contract
│   └── reward_pool.move   # Reward distribution contract
└── tests/
    ├── luck_token_tests.move
    └── reward_pool_tests.move
```

## License

MIT

## Links

- [Lucky Day App](https://lucky-day.app)
- [SUI Documentation](https://docs.sui.io)
- [Move Language](https://move-language.github.io/move/)
# sui-luck-token
