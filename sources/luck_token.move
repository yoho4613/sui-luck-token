/// $LUCK Token - Play-to-Earn utility token for Lucky Day gaming platform
/// Standard: SUI Coin (fungible token)
/// Total Supply: 1,000,000,000 LUCK (minted on demand via TreasuryCap)
/// Decimals: 9
module luck::luck_token {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::url;

    /// One-time witness (must be UPPERCASE of module name: luck_token -> LUCK_TOKEN)
    public struct LUCK_TOKEN has drop {}

    /// Initialize the LUCK token currency
    /// Called exactly once at module publish
    #[allow(deprecated_usage)]
    fun init(witness: LUCK_TOKEN, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            9,                                                          // decimals
            b"LUCK",                                                    // symbol
            b"Lucky Token",                                             // name
            b"Play-to-Earn utility token for Lucky Day gaming platform. Earn by playing skill-based mini-games, spend on spins and upgrades.",
            option::some(url::new_unsafe_from_bytes(
                b"https://lucky-day.app/images/luck-token-icon.png"
            )),
            ctx
        );

        // Transfer minting authority to deployer
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));

        // Freeze metadata so it cannot be changed
        transfer::public_freeze_object(metadata);
    }

    /// Mint tokens to a recipient (only TreasuryCap holder can call)
    public fun mint(
        treasury_cap: &mut TreasuryCap<LUCK_TOKEN>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        let minted_coin = coin::mint(treasury_cap, amount, ctx);
        transfer::public_transfer(minted_coin, recipient);
    }

    /// Burn tokens from a coin object
    public fun burn(
        treasury_cap: &mut TreasuryCap<LUCK_TOKEN>,
        coin: Coin<LUCK_TOKEN>,
    ) {
        coin::burn(treasury_cap, coin);
    }

    /// Batch mint tokens to multiple recipients in a single transaction
    /// Used for: reward distribution, airdrop, leaderboard payouts
    public fun mint_batch(
        treasury_cap: &mut TreasuryCap<LUCK_TOKEN>,
        amounts: vector<u64>,
        recipients: vector<address>,
        ctx: &mut TxContext,
    ) {
        let len = vector::length(&amounts);
        assert!(len == vector::length(&recipients), 0); // ELengthMismatch
        assert!(len > 0, 1); // EEmptyBatch

        let mut i = 0;
        while (i < len) {
            let amount = *vector::borrow(&amounts, i);
            let recipient = *vector::borrow(&recipients, i);
            let minted_coin = coin::mint(treasury_cap, amount, ctx);
            transfer::public_transfer(minted_coin, recipient);
            i = i + 1;
        };
    }

    /// Get the total supply of LUCK tokens minted so far
    public fun total_supply(treasury_cap: &TreasuryCap<LUCK_TOKEN>): u64 {
        coin::total_supply(treasury_cap)
    }

    #[test_only]
    /// Test-only init function
    public fun init_for_testing(ctx: &mut TxContext) {
        init(LUCK_TOKEN {}, ctx);
    }
}
