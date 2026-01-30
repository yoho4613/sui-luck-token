/// $LUCK Token - Play-to-Earn utility token for Lucky Day gaming platform
/// Standard: SUI Coin (fungible token)
/// Max Supply: 1,000,000,000 LUCK (hard cap enforced)
/// Decimals: 9
module luck::luck_token {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::url;
    use sui::event;

    // === Constants ===
    /// Maximum supply: 1 billion LUCK (with 9 decimals)
    const MAX_SUPPLY: u64 = 1_000_000_000_000_000_000; // 1B * 10^9

    // === Error Codes ===
    const ENotAdmin: u64 = 0;
    const EPaused: u64 = 1;
    const ENotPaused: u64 = 2;
    const EExceedsMaxSupply: u64 = 3;

    // === Objects ===

    /// One-time witness (must be UPPERCASE of module name: luck_token -> LUCK_TOKEN)
    public struct LUCK_TOKEN has drop {}

    /// Token configuration - controls pause state and admin
    public struct TokenConfig has key {
        id: UID,
        admin: address,
        paused: bool,
    }

    // === Events ===

    public struct TokenPaused has copy, drop {
        admin: address,
    }

    public struct TokenUnpaused has copy, drop {
        admin: address,
    }

    public struct AdminTransferred has copy, drop {
        old_admin: address,
        new_admin: address,
    }

    // === Init ===

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

        // Create token config (shared object for pause control)
        let config = TokenConfig {
            id: object::new(ctx),
            admin: tx_context::sender(ctx),
            paused: false,
        };
        transfer::share_object(config);

        // Transfer minting authority to deployer
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));

        // Freeze metadata so it cannot be changed
        transfer::public_freeze_object(metadata);
    }

    // === Admin Functions ===

    /// Pause all minting operations (emergency use)
    public fun pause(config: &mut TokenConfig, ctx: &TxContext) {
        assert!(config.admin == tx_context::sender(ctx), ENotAdmin);
        assert!(!config.paused, EPaused);

        config.paused = true;

        event::emit(TokenPaused {
            admin: config.admin,
        });
    }

    /// Unpause minting operations
    public fun unpause(config: &mut TokenConfig, ctx: &TxContext) {
        assert!(config.admin == tx_context::sender(ctx), ENotAdmin);
        assert!(config.paused, ENotPaused);

        config.paused = false;

        event::emit(TokenUnpaused {
            admin: config.admin,
        });
    }

    /// Transfer admin role to a new address
    public fun transfer_admin(config: &mut TokenConfig, new_admin: address, ctx: &TxContext) {
        assert!(config.admin == tx_context::sender(ctx), ENotAdmin);

        let old_admin = config.admin;
        config.admin = new_admin;

        event::emit(AdminTransferred {
            old_admin,
            new_admin,
        });
    }

    // === Mint Functions ===

    /// Mint tokens to a recipient (only TreasuryCap holder can call)
    /// Enforces max supply cap and checks pause state
    public fun mint(
        config: &TokenConfig,
        treasury_cap: &mut TreasuryCap<LUCK_TOKEN>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        assert!(!config.paused, EPaused);
        assert!(coin::total_supply(treasury_cap) + amount <= MAX_SUPPLY, EExceedsMaxSupply);

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
    /// Enforces max supply cap and checks pause state
    public fun mint_batch(
        config: &TokenConfig,
        treasury_cap: &mut TreasuryCap<LUCK_TOKEN>,
        amounts: vector<u64>,
        recipients: vector<address>,
        ctx: &mut TxContext,
    ) {
        assert!(!config.paused, EPaused);

        let len = vector::length(&amounts);
        assert!(len == vector::length(&recipients), 0); // ELengthMismatch
        assert!(len > 0, 1); // EEmptyBatch

        // Calculate total amount to mint
        let mut total_amount: u64 = 0;
        let mut i = 0;
        while (i < len) {
            total_amount = total_amount + *vector::borrow(&amounts, i);
            i = i + 1;
        };

        // Check max supply
        assert!(coin::total_supply(treasury_cap) + total_amount <= MAX_SUPPLY, EExceedsMaxSupply);

        // Mint to all recipients
        i = 0;
        while (i < len) {
            let amount = *vector::borrow(&amounts, i);
            let recipient = *vector::borrow(&recipients, i);
            let minted_coin = coin::mint(treasury_cap, amount, ctx);
            transfer::public_transfer(minted_coin, recipient);
            i = i + 1;
        };
    }

    // === View Functions ===

    /// Get the total supply of LUCK tokens minted so far
    public fun total_supply(treasury_cap: &TreasuryCap<LUCK_TOKEN>): u64 {
        coin::total_supply(treasury_cap)
    }

    /// Get the maximum supply cap
    public fun max_supply(): u64 {
        MAX_SUPPLY
    }

    /// Get remaining mintable tokens
    public fun remaining_supply(treasury_cap: &TreasuryCap<LUCK_TOKEN>): u64 {
        MAX_SUPPLY - coin::total_supply(treasury_cap)
    }

    /// Check if token is paused
    public fun is_paused(config: &TokenConfig): bool {
        config.paused
    }

    /// Get config admin
    public fun config_admin(config: &TokenConfig): address {
        config.admin
    }

    // === Test Functions ===

    #[test_only]
    /// Test-only init function
    public fun init_for_testing(ctx: &mut TxContext) {
        init(LUCK_TOKEN {}, ctx);
    }
}
