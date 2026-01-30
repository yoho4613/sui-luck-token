#[test_only]
module luck::luck_token_tests {
    use sui::coin::{Self, TreasuryCap};
    use sui::test_scenario::{Self as ts, Scenario};
    use luck::luck_token::{Self, LUCK_TOKEN};

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
    fun test_init_creates_treasury_cap() {
        let mut scenario = ts::begin(ADMIN);
        setup_token(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            assert!(ts::has_most_recent_for_sender<TreasuryCap<LUCK_TOKEN>>(&scenario), 0);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_mint_to_recipient() {
        let mut scenario = ts::begin(ADMIN);
        setup_token(&mut scenario);

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<LUCK_TOKEN>>(&scenario);
            luck_token::mint(&mut treasury_cap, 1000_000_000_000, USER1, ts::ctx(&mut scenario));
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
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<LUCK_TOKEN>>(&scenario);

            assert!(luck_token::total_supply(&treasury_cap) == 0, 0);

            luck_token::mint(&mut treasury_cap, 500_000_000_000, USER1, ts::ctx(&mut scenario));
            assert!(luck_token::total_supply(&treasury_cap) == 500_000_000_000, 1);

            luck_token::mint(&mut treasury_cap, 300_000_000_000, USER2, ts::ctx(&mut scenario));
            assert!(luck_token::total_supply(&treasury_cap) == 800_000_000_000, 2);

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
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<LUCK_TOKEN>>(&scenario);
            luck_token::mint(&mut treasury_cap, 1000_000_000_000, ADMIN, ts::ctx(&mut scenario));
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
            let mut treasury_cap = ts::take_from_sender<TreasuryCap<LUCK_TOKEN>>(&scenario);

            let amounts = vector[100_000_000_000, 200_000_000_000, 300_000_000_000];
            let recipients = vector[USER1, USER2, ADMIN];

            luck_token::mint_batch(&mut treasury_cap, amounts, recipients, ts::ctx(&mut scenario));

            assert!(luck_token::total_supply(&treasury_cap) == 600_000_000_000, 0);

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
}
