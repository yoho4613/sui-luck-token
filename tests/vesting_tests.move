#[test_only]
module luck::vesting_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::clock::{Self, Clock};
    use sui::coin::{Self, Coin, TreasuryCap};
    use luck::luck_token::{Self, LUCK_TOKEN};
    use luck::vesting::{Self, VestingSchedule, VestingRegistry};

    // Test constants
    const ADMIN: address = @0xAD;
    const BENEFICIARY: address = @0xBE;
    const ONE_DAY_MS: u64 = 86_400_000;         // 1 day in ms
    const ONE_MONTH_MS: u64 = 2_592_000_000;    // 30 days in ms
    const ONE_YEAR_MS: u64 = 31_536_000_000;    // 365 days in ms

    // Helper: Setup test with LUCK token
    fun setup_test(): Scenario {
        let mut scenario = ts::begin(ADMIN);

        // Initialize LUCK token
        ts::next_tx(&mut scenario, ADMIN);
        {
            luck_token::init_for_testing(ts::ctx(&mut scenario));
        };

        scenario
    }

    // Helper: Mint LUCK tokens
    fun mint_luck(scenario: &mut Scenario, amount: u64): Coin<LUCK_TOKEN> {
        ts::next_tx(scenario, ADMIN);
        let mut treasury_cap = ts::take_from_sender<TreasuryCap<LUCK_TOKEN>>(scenario);
        let coin = coin::mint(&mut treasury_cap, amount, ts::ctx(scenario));
        ts::return_to_sender(scenario, treasury_cap);
        coin
    }

    #[test]
    fun test_create_registry() {
        let mut scenario = setup_test();

        ts::next_tx(&mut scenario, ADMIN);
        {
            vesting::create_registry(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let registry = ts::take_shared<VestingRegistry>(&scenario);
            assert!(vesting::registry_total_schedules(&registry) == 0);
            assert!(vesting::registry_total_locked(&registry) == 0);
            assert!(vesting::registry_total_released(&registry) == 0);
            ts::return_shared(registry);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_create_schedule() {
        let mut scenario = setup_test();

        // Create registry
        ts::next_tx(&mut scenario, ADMIN);
        {
            vesting::create_registry(ts::ctx(&mut scenario));
        };

        // Mint tokens and create schedule
        let tokens = mint_luck(&mut scenario, 1_000_000_000_000); // 1000 LUCK

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = ts::take_shared<VestingRegistry>(&scenario);

            // VC vesting: 12 month cliff + 24 month linear
            vesting::create_schedule(
                &mut registry,
                tokens,
                BENEFICIARY,
                0,                      // start_time (now)
                ONE_YEAR_MS,            // 12 month cliff
                ONE_YEAR_MS * 2,        // 24 month vesting
                false,                  // not revocable
                ts::ctx(&mut scenario)
            );

            assert!(vesting::registry_total_schedules(&registry) == 1);
            assert!(vesting::registry_total_locked(&registry) == 1_000_000_000_000);

            ts::return_shared(registry);
        };

        // Verify schedule is transferred to beneficiary
        ts::next_tx(&mut scenario, BENEFICIARY);
        {
            let schedule = ts::take_from_sender<VestingSchedule>(&scenario);
            assert!(vesting::schedule_beneficiary(&schedule) == BENEFICIARY);
            assert!(vesting::schedule_total_amount(&schedule) == 1_000_000_000_000);
            assert!(vesting::schedule_released_amount(&schedule) == 0);
            assert!(vesting::schedule_cliff_duration(&schedule) == ONE_YEAR_MS);
            assert!(vesting::schedule_vesting_duration(&schedule) == ONE_YEAR_MS * 2);
            assert!(!vesting::schedule_revocable(&schedule));
            assert!(!vesting::schedule_revoked(&schedule));
            ts::return_to_sender(&scenario, schedule);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_release_after_cliff() {
        let mut scenario = setup_test();

        // Create registry
        ts::next_tx(&mut scenario, ADMIN);
        {
            vesting::create_registry(ts::ctx(&mut scenario));
        };

        // Create clock
        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::share_for_testing(clock);
        };

        // Mint tokens and create schedule
        let tokens = mint_luck(&mut scenario, 1_000_000_000_000); // 1000 LUCK

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = ts::take_shared<VestingRegistry>(&scenario);

            // 1 month cliff + 12 month linear
            vesting::create_schedule(
                &mut registry,
                tokens,
                BENEFICIARY,
                0,                      // start_time
                ONE_MONTH_MS,           // 1 month cliff
                ONE_YEAR_MS,            // 12 month vesting
                false,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Advance clock to 7 months (1 month cliff + 6 months vesting = 50%)
        ts::next_tx(&mut scenario, BENEFICIARY);
        {
            let mut clock = ts::take_shared<Clock>(&scenario);
            clock::set_for_testing(&mut clock, ONE_MONTH_MS + (ONE_YEAR_MS / 2));
            ts::return_shared(clock);
        };

        // Release vested tokens
        ts::next_tx(&mut scenario, BENEFICIARY);
        {
            let mut registry = ts::take_shared<VestingRegistry>(&scenario);
            let mut schedule = ts::take_from_sender<VestingSchedule>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);

            vesting::release(&mut registry, &mut schedule, &clock, ts::ctx(&mut scenario));

            // Should have released ~50% (6/12 months of vesting)
            let released = vesting::schedule_released_amount(&schedule);
            assert!(released > 400_000_000_000 && released < 600_000_000_000); // ~50% tolerance

            ts::return_shared(registry);
            ts::return_to_sender(&scenario, schedule);
            ts::return_shared(clock);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_full_vesting() {
        let mut scenario = setup_test();

        // Create registry
        ts::next_tx(&mut scenario, ADMIN);
        {
            vesting::create_registry(ts::ctx(&mut scenario));
        };

        // Create clock
        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::share_for_testing(clock);
        };

        // Mint tokens and create schedule
        let tokens = mint_luck(&mut scenario, 1_000_000_000_000);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = ts::take_shared<VestingRegistry>(&scenario);

            // 1 month cliff + 12 month linear
            vesting::create_schedule(
                &mut registry,
                tokens,
                BENEFICIARY,
                0,
                ONE_MONTH_MS,
                ONE_YEAR_MS,
                false,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Advance clock past full vesting (13 months)
        ts::next_tx(&mut scenario, BENEFICIARY);
        {
            let mut clock = ts::take_shared<Clock>(&scenario);
            clock::set_for_testing(&mut clock, ONE_MONTH_MS + ONE_YEAR_MS + ONE_DAY_MS);
            ts::return_shared(clock);
        };

        // Release all tokens
        ts::next_tx(&mut scenario, BENEFICIARY);
        {
            let mut registry = ts::take_shared<VestingRegistry>(&scenario);
            let mut schedule = ts::take_from_sender<VestingSchedule>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);

            vesting::release(&mut registry, &mut schedule, &clock, ts::ctx(&mut scenario));

            // Should have released 100%
            assert!(vesting::schedule_released_amount(&schedule) == 1_000_000_000_000);
            assert!(vesting::schedule_remaining(&schedule) == 0);

            ts::return_shared(registry);
            ts::return_to_sender(&scenario, schedule);
            ts::return_shared(clock);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = luck::vesting::ENothingToRelease)]
    fun test_release_before_cliff_fails() {
        let mut scenario = setup_test();

        // Create registry
        ts::next_tx(&mut scenario, ADMIN);
        {
            vesting::create_registry(ts::ctx(&mut scenario));
        };

        // Create clock
        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::share_for_testing(clock);
        };

        // Mint tokens and create schedule
        let tokens = mint_luck(&mut scenario, 1_000_000_000_000);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = ts::take_shared<VestingRegistry>(&scenario);

            vesting::create_schedule(
                &mut registry,
                tokens,
                BENEFICIARY,
                0,
                ONE_YEAR_MS,     // 12 month cliff
                ONE_YEAR_MS * 2, // 24 month vesting
                false,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Try to release before cliff (at 6 months)
        ts::next_tx(&mut scenario, BENEFICIARY);
        {
            let mut clock = ts::take_shared<Clock>(&scenario);
            clock::set_for_testing(&mut clock, ONE_YEAR_MS / 2); // 6 months
            ts::return_shared(clock);
        };

        ts::next_tx(&mut scenario, BENEFICIARY);
        {
            let mut registry = ts::take_shared<VestingRegistry>(&scenario);
            let mut schedule = ts::take_from_sender<VestingSchedule>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);

            // This should fail - nothing to release before cliff
            vesting::release(&mut registry, &mut schedule, &clock, ts::ctx(&mut scenario));

            ts::return_shared(registry);
            ts::return_to_sender(&scenario, schedule);
            ts::return_shared(clock);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_revoke_schedule() {
        let mut scenario = setup_test();

        // Create registry
        ts::next_tx(&mut scenario, ADMIN);
        {
            vesting::create_registry(ts::ctx(&mut scenario));
        };

        // Create clock
        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::share_for_testing(clock);
        };

        // Mint tokens and create REVOCABLE schedule
        let tokens = mint_luck(&mut scenario, 1_000_000_000_000);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = ts::take_shared<VestingRegistry>(&scenario);

            vesting::create_schedule(
                &mut registry,
                tokens,
                BENEFICIARY,
                0,
                ONE_MONTH_MS,
                ONE_YEAR_MS,
                true,            // REVOCABLE
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Advance clock to 4 months (1 month cliff + 3 months vesting = 25%)
        ts::next_tx(&mut scenario, BENEFICIARY);
        {
            let mut clock = ts::take_shared<Clock>(&scenario);
            clock::set_for_testing(&mut clock, ONE_MONTH_MS + (ONE_YEAR_MS / 4));
            ts::return_shared(clock);
        };

        // Admin revokes the schedule
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = ts::take_shared<VestingRegistry>(&scenario);
            let mut schedule = ts::take_from_address<VestingSchedule>(&scenario, BENEFICIARY);
            let clock = ts::take_shared<Clock>(&scenario);

            vesting::revoke(&mut registry, &mut schedule, &clock, ts::ctx(&mut scenario));

            assert!(vesting::schedule_revoked(&schedule));
            assert!(vesting::schedule_remaining(&schedule) == 0);

            ts::return_shared(registry);
            ts::return_to_address(BENEFICIARY, schedule);
            ts::return_shared(clock);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = luck::vesting::ENotRevocable)]
    fun test_revoke_non_revocable_fails() {
        let mut scenario = setup_test();

        // Create registry
        ts::next_tx(&mut scenario, ADMIN);
        {
            vesting::create_registry(ts::ctx(&mut scenario));
        };

        // Create clock
        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::share_for_testing(clock);
        };

        // Mint tokens and create NON-REVOCABLE schedule
        let tokens = mint_luck(&mut scenario, 1_000_000_000_000);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = ts::take_shared<VestingRegistry>(&scenario);

            vesting::create_schedule(
                &mut registry,
                tokens,
                BENEFICIARY,
                0,
                ONE_MONTH_MS,
                ONE_YEAR_MS,
                false,           // NOT REVOCABLE
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        // Try to revoke - should fail
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut registry = ts::take_shared<VestingRegistry>(&scenario);
            let mut schedule = ts::take_from_address<VestingSchedule>(&scenario, BENEFICIARY);
            let clock = ts::take_shared<Clock>(&scenario);

            vesting::revoke(&mut registry, &mut schedule, &clock, ts::ctx(&mut scenario));

            ts::return_shared(registry);
            ts::return_to_address(BENEFICIARY, schedule);
            ts::return_shared(clock);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = luck::vesting::ENotAdmin)]
    fun test_create_schedule_not_admin_fails() {
        let mut scenario = setup_test();

        // Create registry
        ts::next_tx(&mut scenario, ADMIN);
        {
            vesting::create_registry(ts::ctx(&mut scenario));
        };

        // Mint tokens (as admin)
        let tokens = mint_luck(&mut scenario, 1_000_000_000_000);

        // Try to create schedule as non-admin
        ts::next_tx(&mut scenario, BENEFICIARY);
        {
            let mut registry = ts::take_shared<VestingRegistry>(&scenario);

            vesting::create_schedule(
                &mut registry,
                tokens,
                BENEFICIARY,
                0,
                ONE_MONTH_MS,
                ONE_YEAR_MS,
                false,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(registry);
        };

        ts::end(scenario);
    }
}
