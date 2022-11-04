// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

// Coin for reward 
module expansion::coin {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct XCOIN has drop {}

    fun init(witness: XCOIN, ctx: &mut TxContext) {
        let treasury_cap = coin::create_currency<XCOIN>(witness, 6, ctx);
        transfer::transfer(treasury_cap, tx_context::sender(ctx))
    }

    public entry fun mint(
        treasury_cap: &mut TreasuryCap<XCOIN>, amount: u64, recipient: address, ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(treasury_cap, amount, recipient, ctx)
    }

    public entry fun burn(treasury_cap: &mut TreasuryCap<XCOIN>, coin: Coin<XCOIN>) {
        coin::burn(treasury_cap, coin);
    }

    #[test_only]
    /// Wrapper of module initializer for testing
    public fun test_init(ctx: &mut TxContext) {
        init(XCOIN {}, ctx)
    }
}