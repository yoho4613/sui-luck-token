#[test_only]
module luck::reward_pool_tests {
    use sui::coin::{Self};
    use sui::sui::SUI;
    use sui::test_scenario::{Self as ts, Scenario};
    use luck::reward_pool::{Self, RewardPool};

    const ADMIN: address = @0xAD;
    const USER1: address = @0xA1;
    const USER2: address = @0xA2;
    const USER3: address = @0xA3;
    const NOT_ADMIN: address = @0xBA;

    fun setup_pool(scenario: &mut Scenario) {
        ts::next_tx(scenario, ADMIN);
        {
            reward_pool::create_pool(ts::ctx(scenario));
        };
    }

    fun deposit_sui(scenario: &mut Scenario, amount: u64) {
        ts::next_tx(scenario, ADMIN);
        {
            let mut pool = ts::take_shared<RewardPool>(scenario);
            let payment = coin::mint_for_testing<SUI>(amount, ts::ctx(scenario));
            reward_pool::deposit(&mut pool, payment, ts::ctx(scenario));
            ts::return_shared(pool);
        };
    }

    #[test]
    fun test_create_pool() {
        let mut scenario = ts::begin(ADMIN);
        setup_pool(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let pool = ts::take_shared<RewardPool>(&scenario);
            assert!(reward_pool::pool_balance(&pool) == 0, 0);
            assert!(reward_pool::pool_admin(&pool) == ADMIN, 1);
            assert!(reward_pool::pool_total_distributed(&pool) == 0, 2);
            assert!(reward_pool::pool_total_deposited(&pool) == 0, 3);
            assert!(reward_pool::pool_distribution_count(&pool) == 0, 4);
            ts::return_shared(pool);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_deposit() {
        let mut scenario = ts::begin(ADMIN);
        setup_pool(&mut scenario);
        deposit_sui(&mut scenario, 10_000_000_000);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let pool = ts::take_shared<RewardPool>(&scenario);
            assert!(reward_pool::pool_balance(&pool) == 10_000_000_000, 0);
            assert!(reward_pool::pool_total_deposited(&pool) == 10_000_000_000, 1);
            ts::return_shared(pool);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = reward_pool::ENotAdmin)]
    fun test_deposit_not_admin_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_pool(&mut scenario);

        ts::next_tx(&mut scenario, NOT_ADMIN);
        {
            let mut pool = ts::take_shared<RewardPool>(&scenario);
            let payment = coin::mint_for_testing<SUI>(1_000_000_000, ts::ctx(&mut scenario));
            reward_pool::deposit(&mut pool, payment, ts::ctx(&mut scenario));
            ts::return_shared(pool);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_distribute_reward() {
        let mut scenario = ts::begin(ADMIN);
        setup_pool(&mut scenario);
        deposit_sui(&mut scenario, 10_000_000_000);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pool = ts::take_shared<RewardPool>(&scenario);
            reward_pool::distribute_reward(&mut pool, 1_000_000_000, USER1, ts::ctx(&mut scenario));
            assert!(reward_pool::pool_balance(&pool) == 9_000_000_000, 0);
            assert!(reward_pool::pool_total_distributed(&pool) == 1_000_000_000, 1);
            assert!(reward_pool::pool_distribution_count(&pool) == 1, 2);
            ts::return_shared(pool);
        };

        ts::next_tx(&mut scenario, USER1);
        {
            let coin = ts::take_from_sender<coin::Coin<SUI>>(&scenario);
            assert!(coin::value(&coin) == 1_000_000_000, 3);
            ts::return_to_sender(&scenario, coin);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = reward_pool::ENotAdmin)]
    fun test_distribute_not_admin_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_pool(&mut scenario);
        deposit_sui(&mut scenario, 10_000_000_000);

        ts::next_tx(&mut scenario, NOT_ADMIN);
        {
            let mut pool = ts::take_shared<RewardPool>(&scenario);
            reward_pool::distribute_reward(&mut pool, 1_000_000_000, USER1, ts::ctx(&mut scenario));
            ts::return_shared(pool);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = reward_pool::EInsufficientBalance)]
    fun test_distribute_insufficient_balance_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_pool(&mut scenario);
        deposit_sui(&mut scenario, 1_000_000_000);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pool = ts::take_shared<RewardPool>(&scenario);
            reward_pool::distribute_reward(&mut pool, 5_000_000_000, USER1, ts::ctx(&mut scenario));
            ts::return_shared(pool);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_distribute_batch() {
        let mut scenario = ts::begin(ADMIN);
        setup_pool(&mut scenario);
        deposit_sui(&mut scenario, 10_000_000_000);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pool = ts::take_shared<RewardPool>(&scenario);
            let amounts = vector[3_000_000_000, 2_000_000_000, 1_000_000_000];
            let recipients = vector[USER1, USER2, USER3];
            reward_pool::distribute_batch(&mut pool, amounts, recipients, ts::ctx(&mut scenario));

            assert!(reward_pool::pool_balance(&pool) == 4_000_000_000, 0);
            assert!(reward_pool::pool_total_distributed(&pool) == 6_000_000_000, 1);
            assert!(reward_pool::pool_distribution_count(&pool) == 3, 2);
            ts::return_shared(pool);
        };

        ts::next_tx(&mut scenario, USER1);
        {
            let coin = ts::take_from_sender<coin::Coin<SUI>>(&scenario);
            assert!(coin::value(&coin) == 3_000_000_000, 3);
            ts::return_to_sender(&scenario, coin);
        };

        ts::next_tx(&mut scenario, USER2);
        {
            let coin = ts::take_from_sender<coin::Coin<SUI>>(&scenario);
            assert!(coin::value(&coin) == 2_000_000_000, 4);
            ts::return_to_sender(&scenario, coin);
        };

        ts::next_tx(&mut scenario, USER3);
        {
            let coin = ts::take_from_sender<coin::Coin<SUI>>(&scenario);
            assert!(coin::value(&coin) == 1_000_000_000, 5);
            ts::return_to_sender(&scenario, coin);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_transfer_admin() {
        let mut scenario = ts::begin(ADMIN);
        setup_pool(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pool = ts::take_shared<RewardPool>(&scenario);
            reward_pool::transfer_admin(&mut pool, USER1, ts::ctx(&mut scenario));
            assert!(reward_pool::pool_admin(&pool) == USER1, 0);
            ts::return_shared(pool);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = reward_pool::ENotAdmin)]
    fun test_transfer_admin_not_admin_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_pool(&mut scenario);

        ts::next_tx(&mut scenario, NOT_ADMIN);
        {
            let mut pool = ts::take_shared<RewardPool>(&scenario);
            reward_pool::transfer_admin(&mut pool, NOT_ADMIN, ts::ctx(&mut scenario));
            ts::return_shared(pool);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_withdraw() {
        let mut scenario = ts::begin(ADMIN);
        setup_pool(&mut scenario);
        deposit_sui(&mut scenario, 10_000_000_000);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pool = ts::take_shared<RewardPool>(&scenario);
            reward_pool::withdraw(&mut pool, 3_000_000_000, ts::ctx(&mut scenario));
            assert!(reward_pool::pool_balance(&pool) == 7_000_000_000, 0);
            ts::return_shared(pool);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = reward_pool::EZeroAmount)]
    fun test_distribute_zero_amount_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_pool(&mut scenario);
        deposit_sui(&mut scenario, 10_000_000_000);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pool = ts::take_shared<RewardPool>(&scenario);
            reward_pool::distribute_reward(&mut pool, 0, USER1, ts::ctx(&mut scenario));
            ts::return_shared(pool);
        };

        ts::end(scenario);
    }
}
