/// Token Vesting - Time-locked token distribution for investors and team
/// Features:
/// - Cliff period: No tokens released until cliff ends
/// - Linear vesting: Tokens released gradually after cliff
/// - Multiple schedules: Different vesting for VC, Team, Advisors
/// - Revocable option: Admin can revoke unvested tokens (for employees)
module luck::vesting {
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::event;
    use luck::luck_token::LUCK_TOKEN;

    // === Error Codes ===
    #[allow(unused_const)]
    const ENotBeneficiary: u64 = 0;
    const ENotAdmin: u64 = 1;
    #[allow(unused_const)]
    const ECliffNotReached: u64 = 2;
    const ENothingToRelease: u64 = 3;
    const EAlreadyRevoked: u64 = 4;
    const ENotRevocable: u64 = 5;
    const EInvalidSchedule: u64 = 6;
    const EZeroAmount: u64 = 7;

    // === Objects ===

    /// Individual vesting schedule for a beneficiary
    public struct VestingSchedule has key, store {
        id: UID,
        beneficiary: address,
        admin: address,
        total_amount: u64,
        released_amount: u64,
        start_time: u64,          // Unix timestamp (ms)
        cliff_duration: u64,       // Cliff period in ms
        vesting_duration: u64,     // Total vesting period in ms (after cliff)
        revocable: bool,
        revoked: bool,
        balance: Balance<LUCK_TOKEN>,
    }

    /// Registry to track all vesting schedules (optional, for admin view)
    public struct VestingRegistry has key {
        id: UID,
        admin: address,
        total_schedules: u64,
        total_locked: u64,
        total_released: u64,
    }

    // === Events ===

    public struct ScheduleCreated has copy, drop {
        schedule_id: ID,
        beneficiary: address,
        total_amount: u64,
        cliff_duration: u64,
        vesting_duration: u64,
        revocable: bool,
    }

    public struct TokensReleased has copy, drop {
        schedule_id: ID,
        beneficiary: address,
        amount: u64,
        total_released: u64,
    }

    public struct ScheduleRevoked has copy, drop {
        schedule_id: ID,
        beneficiary: address,
        amount_returned: u64,
    }

    public struct RegistryCreated has copy, drop {
        registry_id: ID,
        admin: address,
    }

    // === Public Functions ===

    /// Create a vesting registry (call once by admin)
    public fun create_registry(ctx: &mut TxContext) {
        let registry = VestingRegistry {
            id: object::new(ctx),
            admin: tx_context::sender(ctx),
            total_schedules: 0,
            total_locked: 0,
            total_released: 0,
        };

        event::emit(RegistryCreated {
            registry_id: object::id(&registry),
            admin: tx_context::sender(ctx),
        });

        transfer::share_object(registry);
    }

    /// Create a vesting schedule for a beneficiary
    /// @param tokens - LUCK tokens to vest
    /// @param beneficiary - Address that will receive tokens
    /// @param start_time - Unix timestamp in ms when vesting starts
    /// @param cliff_duration - Time in ms before any tokens can be released
    /// @param vesting_duration - Time in ms for linear vesting (after cliff)
    /// @param revocable - Whether admin can revoke unvested tokens
    public fun create_schedule(
        registry: &mut VestingRegistry,
        tokens: Coin<LUCK_TOKEN>,
        beneficiary: address,
        start_time: u64,
        cliff_duration: u64,
        vesting_duration: u64,
        revocable: bool,
        ctx: &mut TxContext,
    ) {
        assert!(registry.admin == tx_context::sender(ctx), ENotAdmin);

        let total_amount = coin::value(&tokens);
        assert!(total_amount > 0, EZeroAmount);
        assert!(vesting_duration > 0, EInvalidSchedule);

        let schedule = VestingSchedule {
            id: object::new(ctx),
            beneficiary,
            admin: registry.admin,
            total_amount,
            released_amount: 0,
            start_time,
            cliff_duration,
            vesting_duration,
            revocable,
            revoked: false,
            balance: coin::into_balance(tokens),
        };

        // Update registry
        registry.total_schedules = registry.total_schedules + 1;
        registry.total_locked = registry.total_locked + total_amount;

        event::emit(ScheduleCreated {
            schedule_id: object::id(&schedule),
            beneficiary,
            total_amount,
            cliff_duration,
            vesting_duration,
            revocable,
        });

        // Transfer schedule to beneficiary (they own it, can call release)
        transfer::transfer(schedule, beneficiary);
    }

    /// Release vested tokens to beneficiary
    /// Anyone can call this, but tokens go to the beneficiary
    public fun release(
        registry: &mut VestingRegistry,
        schedule: &mut VestingSchedule,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        assert!(!schedule.revoked, EAlreadyRevoked);

        let current_time = clock::timestamp_ms(clock);
        let releasable = calculate_releasable(schedule, current_time);

        assert!(releasable > 0, ENothingToRelease);

        // Update released amount
        schedule.released_amount = schedule.released_amount + releasable;
        registry.total_released = registry.total_released + releasable;

        // Transfer tokens to beneficiary
        let release_coin = coin::from_balance(
            balance::split(&mut schedule.balance, releasable),
            ctx
        );
        transfer::public_transfer(release_coin, schedule.beneficiary);

        event::emit(TokensReleased {
            schedule_id: object::uid_to_inner(&schedule.id),
            beneficiary: schedule.beneficiary,
            amount: releasable,
            total_released: schedule.released_amount,
        });
    }

    /// Revoke unvested tokens (admin only, only if revocable)
    public fun revoke(
        registry: &mut VestingRegistry,
        schedule: &mut VestingSchedule,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        assert!(schedule.admin == tx_context::sender(ctx), ENotAdmin);
        assert!(schedule.revocable, ENotRevocable);
        assert!(!schedule.revoked, EAlreadyRevoked);

        let current_time = clock::timestamp_ms(clock);

        // First, release any vested tokens to beneficiary
        let releasable = calculate_releasable(schedule, current_time);
        if (releasable > 0) {
            schedule.released_amount = schedule.released_amount + releasable;
            registry.total_released = registry.total_released + releasable;

            let release_coin = coin::from_balance(
                balance::split(&mut schedule.balance, releasable),
                ctx
            );
            transfer::public_transfer(release_coin, schedule.beneficiary);
        };

        // Return remaining unvested tokens to admin
        let remaining = balance::value(&schedule.balance);
        if (remaining > 0) {
            registry.total_locked = registry.total_locked - remaining;

            let return_coin = coin::from_balance(
                balance::withdraw_all(&mut schedule.balance),
                ctx
            );
            transfer::public_transfer(return_coin, schedule.admin);
        };

        schedule.revoked = true;

        event::emit(ScheduleRevoked {
            schedule_id: object::uid_to_inner(&schedule.id),
            beneficiary: schedule.beneficiary,
            amount_returned: remaining,
        });
    }

    // === View Functions ===

    /// Calculate how many tokens can be released right now
    public fun calculate_releasable(schedule: &VestingSchedule, current_time: u64): u64 {
        if (schedule.revoked) {
            return 0
        };

        let vested = calculate_vested(schedule, current_time);
        if (vested > schedule.released_amount) {
            vested - schedule.released_amount
        } else {
            0
        }
    }

    /// Calculate total vested amount at a given time
    public fun calculate_vested(schedule: &VestingSchedule, current_time: u64): u64 {
        // Before start time
        if (current_time < schedule.start_time) {
            return 0
        };

        let elapsed = current_time - schedule.start_time;

        // Still in cliff period
        if (elapsed < schedule.cliff_duration) {
            return 0
        };

        // After cliff, calculate linear vesting
        let time_after_cliff = elapsed - schedule.cliff_duration;

        if (time_after_cliff >= schedule.vesting_duration) {
            // Fully vested
            schedule.total_amount
        } else {
            // Partial vesting (linear)
            let vested = (schedule.total_amount as u128) * (time_after_cliff as u128)
                        / (schedule.vesting_duration as u128);
            (vested as u64)
        }
    }

    /// Get schedule info
    public fun schedule_beneficiary(schedule: &VestingSchedule): address {
        schedule.beneficiary
    }

    public fun schedule_total_amount(schedule: &VestingSchedule): u64 {
        schedule.total_amount
    }

    public fun schedule_released_amount(schedule: &VestingSchedule): u64 {
        schedule.released_amount
    }

    public fun schedule_remaining(schedule: &VestingSchedule): u64 {
        balance::value(&schedule.balance)
    }

    public fun schedule_start_time(schedule: &VestingSchedule): u64 {
        schedule.start_time
    }

    public fun schedule_cliff_duration(schedule: &VestingSchedule): u64 {
        schedule.cliff_duration
    }

    public fun schedule_vesting_duration(schedule: &VestingSchedule): u64 {
        schedule.vesting_duration
    }

    public fun schedule_revocable(schedule: &VestingSchedule): bool {
        schedule.revocable
    }

    public fun schedule_revoked(schedule: &VestingSchedule): bool {
        schedule.revoked
    }

    /// Get registry info
    public fun registry_total_schedules(registry: &VestingRegistry): u64 {
        registry.total_schedules
    }

    public fun registry_total_locked(registry: &VestingRegistry): u64 {
        registry.total_locked
    }

    public fun registry_total_released(registry: &VestingRegistry): u64 {
        registry.total_released
    }
}
