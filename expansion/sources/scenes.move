// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

// Harvesting energy around an expanding and contracting energy source.
// The closer you are to the energy source, the more energy you get,
// but at the same time there is a risk of being swallowed.

// 1) Create a scense, including the energy source, an empty participant set.
// 2) A centralized service advancement scenario by a certain interval
// 3) Energy will shrink and expand depending on the energy being drawn.
//    It has an equilibrium point and always moves towards the equilibrium point.
// 4) Participant can move at will.
// 5) Participant must stake some assets. The ultimate winner will receive all staking assets.

// all participant in pool.
// advancement scenario 
//  1. change energy boundary     
//  2. calculate energy of all participant

module expansion::scenes{
    use sui::object::{Self, UID};
    use sui::vec_map::{Self, VecMap};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use expansion::coin::{XCOIN};    

    struct EnergySource has copy, drop, store {
        power: u64,
        radius: u64,
        equilibrium: u64,
        attenuation_factor: u64,
    }

    struct Participant has store {
        distance: u64,
        energy: u64,
    }

    struct Scene has key{
        id: UID,
        energy_source: EnergySource,
        participants: VecMap<address, Participant>,
        min_stake: u64,
        total_stake: Coin<XCOIN>,
    }

    public entry fun create_scence(ctx: &mut TxContext, source: &EnergySource, min_stake: u64,){
        transfer::transfer(
            Scene{
                id: object::new(ctx),
                energy_source: *source,
                participants: vec_map::empty(),
                min_stake,
                total_stake: coin::zero(ctx),
            },
            tx_context::sender(ctx)
        )
    }

    public entry fun participant_enter(
        ctx: &mut TxContext, 
        scene: &mut Scene,
        participant_address: address,
        stakes: Coin<XCOIN>)
    {
        coin::join(&mut scene.total_stake, stakes);
    }

    public entry fun participant_move(ctx: &mut TxContext, distance: u64, forward: bool){

    }

    public entry fun advance_scene(ctx: &mut TxContext, scene: &mut Scene){

    }

    public entry fun end_scene(ctx: &mut TxContext, scene: &mut Scene){

    }
}