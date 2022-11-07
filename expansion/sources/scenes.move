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

module expansion::scenes{
    use sui::object::{Self, UID};
    use std::vector::{Self};
    use sui::vec_map::{Self, VecMap};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::balance;

    use expansion::priority_queue::{Self, PriorityQueue, Entry};
    use expansion::coin::{XCOIN};    

    const E_INSUFFICIENT_COIN: u64 = 0;
    const E_MAX_PARTICIPANT: u64 = 1;
    const E_NOT_ALIVE: u64 = 2;
    const E_PARTICIPANT_NOT_EXIST: u64 = 3;
    const E_NOT_NEXT_FRAME: u64 = 4;
    const E_NOT_END: u64 = 5;

    struct EnergySource has copy, drop, store {
        power: u64,
        radius: u64,
        equilibrium: u64,
        attenuation_factor: u64,
    }

    struct ParticipantInfo has drop, key, store {
        id : address,
        energy: u64,
        alive: bool,
    }

    struct SceneParams has copy ,store{
        frames: u64,
        frame_interval: u64,
        next_frame_block: u64,
        max_participant: u64,
    }

    struct Scene has key{
        id: UID,
        energy_source: EnergySource,

        participants: VecMap<address, Entry<ParticipantInfo>>,

        parameters: SceneParams,

        min_stake: u64,
        total_stake: Coin<XCOIN>,
    }

    public entry fun create_scence(
        ctx: &mut TxContext,
        source: &EnergySource,
        min_stake: u64,
        parameter: &SceneParams
    ){
        transfer::transfer(
            Scene{
                id: object::new(ctx),
                energy_source: *source,
                participants: vec_map::empty(),
                min_stake,
                total_stake: coin::zero(ctx),
                parameters: *parameter,
            },
            tx_context::sender(ctx)
        )
    }

    public entry fun participant_enter(
        ctx: &mut TxContext,
        scene: &mut Scene,
        participant_address: address,
        stakes: Coin<XCOIN>,
    ){
        assert!(coin::value(&stakes) < scene.min_stake, E_INSUFFICIENT_COIN);
        assert!(vec_map::size(&scene.participants) < scene.parameters.max_participant, E_MAX_PARTICIPANT);

        vec_map::insert(&mut scene.participants, participant_address, priority_queue::new_entry(
            scene.energy_source.radius *2, 
            ParticipantInfo{
                id: participant_address,
                energy: 0,
                alive: true,
            },
        ));

        coin::join(&mut scene.total_stake, stakes);
    }

    public entry fun participant_move(
        _ctx: &mut TxContext,
        scene: &mut Scene, 
        participant_address: address,
        distance: u64,
        forward: bool
    ){
        assert!(vec_map::contains(&scene.participants, &participant_address), E_PARTICIPANT_NOT_EXIST);

        let entry = vec_map::get_mut(&mut scene.participants, &participant_address);
        let entry_distance = priority_queue::entry_priority(entry);
        
        if (forward == true) {
            if (entry_distance <= distance){
                priority_queue::set_entry_priority(entry, 0);
            }else{
                priority_queue::set_entry_priority(entry, entry_distance - distance)
            }
        }else{
            priority_queue::set_entry_priority(entry, entry_distance + distance)
        }
    }

    // advance scene by frame
    //  1. change energy boundary
    //  2. calculate energy of all alive participant
    public entry fun advance_scene(ctx: &mut TxContext, scene: &mut Scene){
        assert!(scene.parameters.next_frame_block <= tx_context::epoch(ctx), E_NOT_NEXT_FRAME);

        let n = vec_map::size(&scene.participants);
        let consumed_energy: u64 = 0;
        let alive_min_distance: u64 = 0;
        let alive_participants = vec_map::empty();
        let all_participant = vector::empty();
        let i = 0;

        while (i < n) {
            let (_, participant) = vec_map::pop(&mut scene.participants);
            vector::push_back(&mut all_participant, participant);
            i = i + 1;
        };

        let j = 0;

        let participant = priority_queue<ParticipantInfo>::new(all_participant);    

        while (j < n) {
            let participant = priority_queue::pop(&mut participant);
            let participant_distance = priority_queue<ParticipantInfo>::entry_priority(&participant);

            let received = calcualte_receive_energy(scene.energy_source.power, participant_distance);
            consumed_energy = consumed_energy + received;
            if (consumed_energy > scene.energy_source.equilibrium) {
                alive_min_distance = participant_distance;
                break;
            };

            participant.energy = participant.energy + received;

            vec_map::insert(&mut alive_participants, key, participant);
            j = j +1;
        };

        // if alive_min_distance be setted. Then energy source change radius and some participant will dead.
        if (alive_min_distance != 0) {
            scene.energy_source.radius = alive_min_distance;
            scene.participants = alive_participants;
        };

        scene.parameters.frames = scene.parameters.frames - 1;
        scene.parameters.next_frame_block = tx_context::epoch(ctx) + scene.parameters.frame_interval;
    }

    public entry fun end_scene(ctx: &mut TxContext, scene: &mut Scene){
        assert!(scene.frames == 0, E_NOT_END);
        let max_recevie_energy = 0;
        let winers = vector::empty();
        let n = vec_map::size(&scene.participants);
        let i = 0;
        while (i < n) {
            let (key, participant) = vec_map::pop(&mut scene.participants);
            if (participant.energy < max_recevie_energy){
                continue;
            };

            if (participant.energy > max_recevie_energy){
                winers = vector::empty();   
            };

            vector::push_back(&mut winers, key);
            i = i + 1;
        };

        let n_winers = vector::size(&winers);
        let coin_value = balance::value(&coin::into_balance(scene.total_stake));
        let reward = coin_value / n_winers;
        
        let i = 0;
        let n = vector::size(&winers);
        let reward = coin_value / n;
        while( i < n){
            let reward_balance = balance::split(&coin::into_balance(scene.total_stake), reward);
            transfer::transfer(coin::from_balance(reward_balance), vector::borrow(i));
            i = i + 1;
        }
    }

    fun calcualte_receive_energy(distance: u64, energy_intensity: u64): u64{
        energy_intensity / distance
    }
}