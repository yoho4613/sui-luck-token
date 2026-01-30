#[test_only]
module luck::luck_token_tests {
    use sui::coin::{Self, TreasuryCap};
    use sui::test_scenario::{Self as ts, Scenario};
    use luck::luck_token::{Self, LUCK_TOKEN, TokenConfig};

    const ADMIN: address = @0xAD;
    const USER1: address = @0xA1;
    const USER2: address = @0xA2;

    fun setup_token(scenario: &mut Scenario) {
        ts::next_tx(scenario, ADMIN);
        {
            luck_token::init_for_testing(ts::ctx(scenario));
        };
    }

    #[test]
    fun test_init_creates_treasury_cap_and_config() {
        let mut scenario = ts::begin(ADMIN);
        setup_token(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            // Treasury cap should be owned by admin
            assert!(ts::has_most_recent_for_sender<TreasuryCap<LUCK_TOKEN>>(&scenario), 0);

            // Config should be shared
            let config = ts::take_shared<TokenConfig>(&scenario);
            assert!(!luck_token::is_paused(&config), 1);
            assert!(luck_token::config_admin(&config) == ADMIN, 2);
            ts::return_shared(config);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_mint_to_recipient() {
        let mut scenario = ts::begin(ADMIN);
        setup_token(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let config = ts::take_shared<TokenConfig>(&scenario);
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<LUCK_TOKEN>>(&scenario);

            luck_token::mint(&config, &mut treasury_cap, 1000_000_000_000, USER1, ts::ctx(&mut scenario));

            ts::return_shared(config);
            ts::return_to_sender(&scenario, treasury_cap);
        };

        ts::next_tx(&mut scenario, USER1);
        {
            let coin = ts::take_from_sender<coin::Coin<LUCK_TOKEN>>(&scenario);
            assert!(coin::value(&coin) == 1000_000_000_000, 1);
            ts::return_to_sender(&scenario, coin);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_total_supply_tracks_correctly() {
        let mut scenario = ts::begin(ADMIN);
        setup_token(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let config = ts::take_shared<TokenConfig>(&scenario);
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<LUCK_TOKEN>>(&scenario);

            assert!(luck_token::total_supply(&treasury_cap) == 0, 0);

            luck_token::mint(&config, &mut treasury_cap, 500_000_000_000, USER1, ts::ctx(&mut scenario));
            assert!(luck_token::total_supply(&treasury_cap) == 500_000_000_000, 1);

            luck_token::mint(&config, &mut treasury_cap, 300_000_000_000, USER2, ts::ctx(&mut scenario));
            assert!(luck_token::total_supply(&treasury_cap) == 800_000_000_000, 2);

            ts::return_shared(config);
            ts::return_to_sender(&scenario, treasury_cap);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_burn_reduces_supply() {
        let mut scenario = ts::begin(ADMIN);
        setup_token(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let config = ts::take_shared<TokenConfig>(&scenario);
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<LUCK_TOKEN>>(&scenario);
            luck_token::mint(&config, &mut treasury_cap, 1000_000_000_000, ADMIN, ts::ctx(&mut scenario));
            ts::return_shared(config);
            ts::return_to_sender(&scenario, treasury_cap);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<LUCK_TOKEN>>(&scenario);
            let mut coin = ts::take_from_sender<coin::Coin<LUCK_TOKEN>>(&scenario);
            let burn_coin = coin::split(&mut coin, 400_000_000_000, ts::ctx(&mut scenario));

            luck_token::burn(&mut treasury_cap, burn_coin);
            assert!(luck_token::total_supply(&treasury_cap) == 600_000_000_000, 0);

            ts::return_to_sender(&scenario, coin);
            ts::return_to_sender(&scenario, treasury_cap);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_mint_batch() {
        let mut scenario = ts::begin(ADMIN);
        setup_token(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let config = ts::take_shared<TokenConfig>(&scenario);
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<LUCK_TOKEN>>(&scenario);

            let amounts = vector[100_000_000_000, 200_000_000_000, 300_000_000_000];
            let recipients = vector[USER1, USER2, ADMIN];

            luck_token::mint_batch(&config, &mut treasury_cap, amounts, recipients, ts::ctx(&mut scenario));

            assert!(luck_token::total_supply(&treasury_cap) == 600_000_000_000, 0);

            ts::return_shared(config);
            ts::return_to_sender(&scenario, treasury_cap);
        };

        ts::next_tx(&mut scenario, USER1);
        {
            let coin = ts::take_from_sender<coin::Coin<LUCK_TOKEN>>(&scenario);
            assert!(coin::value(&coin) == 100_000_000_000, 1);
            ts::return_to_sender(&scenario, coin);
        };

        ts::next_tx(&mut scenario, USER2);
        {
            let coin = ts::take_from_sender<coin::Coin<LUCK_TOKEN>>(&scenario);
            assert!(coin::value(&coin) == 200_000_000_000, 2);
            ts::return_to_sender(&scenario, coin);
        };

        ts::end(scenario);
    }

    // === Pause Tests ===

    #[test]
    fun test_pause_and_unpause() {
        let mut scenario = ts::begin(ADMIN);
        setup_token(&mut scenario);

        // Pause
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut config = ts::take_shared<TokenConfig>(&scenario);
            assert!(!luck_token::is_paused(&config), 0);

            luck_token::pause(&mut config, ts::ctx(&mut scenario));
            assert!(luck_token::is_paused(&config), 1);

            ts::return_shared(config);
        };

        // Unpause
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut config = ts::take_shared<TokenConfig>(&scenario);
            luck_token::unpause(&mut config, ts::ctx(&mut scenario));
            assert!(!luck_token::is_paused(&config), 2);

            ts::return_shared(config);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = luck::luck_token::EPaused)]
    fun test_mint_when_paused_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_token(&mut scenario);

        // Pause
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut config = ts::take_shared<TokenConfig>(&scenario);
            luck_token::pause(&mut config, ts::ctx(&mut scenario));
            ts::return_shared(config);
        };

        // Try to mint (should fail)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let config = ts::take_shared<TokenConfig>(&scenario);
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<LUCK_TOKEN>>(&scenario);

            luck_token::mint(&config, &mut treasury_cap, 1000_000_000_000, USER1, ts::ctx(&mut scenario));

            ts::return_shared(config);
            ts::return_to_sender(&scenario, treasury_cap);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = luck::luck_token::ENotAdmin)]
    fun test_pause_not_admin_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_token(&mut scenario);

        // Try to pause as non-admin
        ts::next_tx(&mut scenario, USER1);
        {
            let mut config = ts::take_shared<TokenConfig>(&scenario);
            luck_token::pause(&mut config, ts::ctx(&mut scenario));
            ts::return_shared(config);
        };

        ts::end(scenario);
    }

    // === Max Supply Tests ===

    #[test]
    fun test_max_supply_constant() {
        // 1 billion with 9 decimals
        assert!(luck_token::max_supply() == 1_000_000_000_000_000_000, 0);
    }

    #[test]
    #[expected_failure(abort_code = luck::luck_token::EExceedsMaxSupply)]
    fun test_mint_exceeds_max_supply_fails() {
        let mut scenario = ts::begin(ADMIN);
        setup_token(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let config = ts::take_shared<TokenConfig>(&scenario);
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<LUCK_TOKEN>>(&scenario);

            // Try to mint more than max supply
            luck_token::mint(
                &config,
                &mut treasury_cap,
                1_000_000_001_000_000_000, // 1B + 1 LUCK
                USER1,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(config);
            ts::return_to_sender(&scenario, treasury_cap);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_remaining_supply() {
        let mut scenario = ts::begin(ADMIN);
        setup_token(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let config = ts::take_shared<TokenConfig>(&scenario);
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<LUCK_TOKEN>>(&scenario);

            // Initial remaining = max supply
            assert!(luck_token::remaining_supply(&treasury_cap) == luck_token::max_supply(), 0);

            // Mint some
            luck_token::mint(&config, &mut treasury_cap, 100_000_000_000_000_000, USER1, ts::ctx(&mut scenario)); // 100M LUCK

            // Remaining should be reduced
            assert!(luck_token::remaining_supply(&treasury_cap) == 900_000_000_000_000_000, 1); // 900M LUCK

            ts::return_shared(config);
            ts::return_to_sender(&scenario, treasury_cap);
        };

        ts::end(scenario);
    }

    // === Admin Transfer Test ===

    #[test]
    fun test_transfer_admin() {
        let mut scenario = ts::begin(ADMIN);
        setup_token(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut config = ts::take_shared<TokenConfig>(&scenario);
            assert!(luck_token::config_admin(&config) == ADMIN, 0);

            luck_token::transfer_admin(&mut config, USER1, ts::ctx(&mut scenario));
            assert!(luck_token::config_admin(&config) == USER1, 1);

            ts::return_shared(config);
        };

        // New admin can pause
        ts::next_tx(&mut scenario, USER1);
        {
            let mut config = ts::take_shared<TokenConfig>(&scenario);
            luck_token::pause(&mut config, ts::ctx(&mut scenario));
            assert!(luck_token::is_paused(&config), 2);
            ts::return_shared(config);
        };

        ts::end(scenario);
    }
}
