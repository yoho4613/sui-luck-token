/// Reward Pool - Holds SUI for prize distribution to game winners
/// Used for: spin rewards (SUI prizes), leaderboard payouts, special events
/// Architecture: Shared object controlled by admin address
module luck::reward_pool {
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::event;

    // === Error Codes ===
    const ENotAdmin: u64 = 0;
    const EInsufficientBalance: u64 = 1;
    const ELengthMismatch: u64 = 2;
    const EEmptyBatch: u64 = 3;
    const EZeroAmount: u64 = 4;

    // === Objects ===

    /// Shared reward pool holding SUI for prizes
    public struct RewardPool has key {
        id: UID,
        balance: Balance<SUI>,
        admin: address,
        total_distributed: u64,
        total_deposited: u64,
        distribution_count: u64,
    }

    // === Events ===

    public struct PoolCreated has copy, drop {
        pool_id: ID,
        admin: address,
    }

    public struct Deposited has copy, drop {
        pool_id: ID,
        amount: u64,
        new_balance: u64,
    }

    public struct RewardDistributed has copy, drop {
        pool_id: ID,
        recipient: address,
        amount: u64,
    }

    public struct BatchDistributed has copy, drop {
        pool_id: ID,
        count: u64,
        total_amount: u64,
    }

    public struct AdminTransferred has copy, drop {
        pool_id: ID,
        old_admin: address,
        new_admin: address,
    }

    // === Public Functions ===

    /// Create the reward pool (called once by admin)
    public fun create_pool(ctx: &mut TxContext) {
        let pool = RewardPool {
            id: object::new(ctx),
            balance: balance::zero(),
            admin: tx_context::sender(ctx),
            total_distributed: 0,
            total_deposited: 0,
            distribution_count: 0,
        };

        event::emit(PoolCreated {
            pool_id: object::id(&pool),
            admin: tx_context::sender(ctx),
        });

        transfer::share_object(pool);
    }

    /// Admin deposits SUI into the reward pool
    public fun deposit(
        pool: &mut RewardPool,
        payment: Coin<SUI>,
        ctx: &TxContext,
    ) {
        assert!(pool.admin == tx_context::sender(ctx), ENotAdmin);

        let amount = coin::value(&payment);
        let payment_balance = coin::into_balance(payment);
        balance::join(&mut pool.balance, payment_balance);
        pool.total_deposited = pool.total_deposited + amount;

        event::emit(Deposited {
            pool_id: object::id(pool),
            amount,
            new_balance: balance::value(&pool.balance),
        });
    }

    /// Distribute SUI reward to a single winner
    public fun distribute_reward(
        pool: &mut RewardPool,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        assert!(pool.admin == tx_context::sender(ctx), ENotAdmin);
        assert!(amount > 0, EZeroAmount);
        assert!(balance::value(&pool.balance) >= amount, EInsufficientBalance);

        let reward_coin = coin::from_balance(
            balance::split(&mut pool.balance, amount),
            ctx
        );
        transfer::public_transfer(reward_coin, recipient);

        pool.total_distributed = pool.total_distributed + amount;
        pool.distribution_count = pool.distribution_count + 1;

        event::emit(RewardDistributed {
            pool_id: object::id(pool),
            recipient,
            amount,
        });
    }

    /// Batch distribute SUI rewards (leaderboard payouts, event prizes)
    /// All transfers execute atomically in a single transaction
    public fun distribute_batch(
        pool: &mut RewardPool,
        amounts: vector<u64>,
        recipients: vector<address>,
        ctx: &mut TxContext,
    ) {
        assert!(pool.admin == tx_context::sender(ctx), ENotAdmin);

        let len = vector::length(&amounts);
        assert!(len == vector::length(&recipients), ELengthMismatch);
        assert!(len > 0, EEmptyBatch);

        let mut total_amount: u64 = 0;
        let mut i = 0;

        while (i < len) {
            let amount = *vector::borrow(&amounts, i);
            let recipient = *vector::borrow(&recipients, i);

            assert!(amount > 0, EZeroAmount);
            assert!(balance::value(&pool.balance) >= amount, EInsufficientBalance);

            let reward_coin = coin::from_balance(
                balance::split(&mut pool.balance, amount),
                ctx
            );
            transfer::public_transfer(reward_coin, recipient);

            total_amount = total_amount + amount;
            i = i + 1;
        };

        pool.total_distributed = pool.total_distributed + total_amount;
        pool.distribution_count = pool.distribution_count + len;

        event::emit(BatchDistributed {
            pool_id: object::id(pool),
            count: len,
            total_amount,
        });
    }

    /// Transfer admin role to a new address
    public fun transfer_admin(
        pool: &mut RewardPool,
        new_admin: address,
        ctx: &TxContext,
    ) {
        assert!(pool.admin == tx_context::sender(ctx), ENotAdmin);

        let old_admin = pool.admin;
        pool.admin = new_admin;

        event::emit(AdminTransferred {
            pool_id: object::id(pool),
            old_admin,
            new_admin,
        });
    }

    /// Admin withdraws SUI from pool (emergency or rebalancing)
    #[allow(lint(self_transfer))]
    public fun withdraw(
        pool: &mut RewardPool,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        assert!(pool.admin == tx_context::sender(ctx), ENotAdmin);
        assert!(amount > 0, EZeroAmount);
        assert!(balance::value(&pool.balance) >= amount, EInsufficientBalance);

        let withdraw_coin = coin::from_balance(
            balance::split(&mut pool.balance, amount),
            ctx
        );
        transfer::public_transfer(withdraw_coin, tx_context::sender(ctx));
    }

    // === View Functions ===

    public fun pool_balance(pool: &RewardPool): u64 {
        balance::value(&pool.balance)
    }

    public fun pool_admin(pool: &RewardPool): address {
        pool.admin
    }

    public fun pool_total_distributed(pool: &RewardPool): u64 {
        pool.total_distributed
    }

    public fun pool_total_deposited(pool: &RewardPool): u64 {
        pool.total_deposited
    }

    public fun pool_distribution_count(pool: &RewardPool): u64 {
        pool.distribution_count
    }
}
