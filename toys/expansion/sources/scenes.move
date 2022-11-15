// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

// Harvesting energy around an expanding and contracting energy source.
// The closer you are to the energy source, the more energy you get,
// but at the same time there is a risk of being swallowed.

module expansion::scenes{
    use std::vector::{Self};

    use sui::object::{Self, UID};
    use sui::vec_map::{Self, VecMap};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::coin::{Self, Coin};

    use expansion::xcoin::{XCOIN};   

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
    }

    struct ParticipantInfo has copy, drop, store {
        energy: u64,
        alive: bool,
        distance: u64,
        id : address,
    }

    struct SceneParams has copy ,store, drop{
        frames: u64,
        frame_interval: u64,
        next_frame_block: u64,
        max_participant: u64,
    }

    struct Scene has key{
        id: UID,
        energy_source: EnergySource,

        participants: VecMap<address, ParticipantInfo>,

        parameters: SceneParams,

        min_stake: u64,
        total_stake: Coin<XCOIN>,
    }

    public entry fun create_scene(
        power: u64,
        radius: u64,
        equilibrium: u64,
        frames: u64,
        frame_interval: u64,
        next_frame_block: u64,
        max_participant: u64,  
        min_stake: u64,
        ctx: &mut TxContext,
    ){
        let source = EnergySource{
            power: power,
            radius: radius,
            equilibrium: equilibrium,
        };
        
        let parameters = SceneParams{
            frames: frames,
            frame_interval: frame_interval,
            next_frame_block: next_frame_block,
            max_participant: max_participant,
        };

        transfer::transfer(
            Scene{
                id: object::new(ctx),
                energy_source: source,
                participants: vec_map::empty(),
                min_stake,
                total_stake: coin::zero(ctx),
                parameters,
            },
            tx_context::sender(ctx)
        )
    }

    public entry fun participant_enter(
        scene: &mut Scene,
        stakes: Coin<XCOIN>,
        participant_address: address,
        _ctx: &mut TxContext,
    ){
        assert!(coin::value(&stakes) >= scene.min_stake, E_INSUFFICIENT_COIN);
        assert!(vec_map::size(&scene.participants) < scene.parameters.max_participant, E_MAX_PARTICIPANT);

        vec_map::insert(&mut scene.participants, participant_address, 
            ParticipantInfo{
                id: participant_address,
                energy: 0,
                alive: true,
                distance: scene.energy_source.radius *2, 
            },
        );

        coin::join(&mut scene.total_stake, stakes);
    }

    // The caller of this function needs control of the scene,
    // Control of the scene may be in the central session service. 
    // In fact, the user submits his mobile parameters to the centralized service 
    // instead of sending transactions to the chain.
    // Maybe we need to make the Scene as a shared object, but will that reduce performance?
    // The same problem exists in `participant_enter` function.
    public entry fun participant_move(
        scene: &mut Scene, 
        participant_address: address,
        distance: u64,
        forward: bool,
        _ctx: &mut TxContext,
    ){
        assert!(vec_map::contains(&scene.participants, &participant_address), E_PARTICIPANT_NOT_EXIST);

        let participant = vec_map::get_mut(&mut scene.participants, &participant_address);
        
        if (forward == true) {
            if (participant.distance <= distance){
                participant.distance = 0;
            }else{
                participant.distance = participant.distance - distance;
            }
        }else{
            participant.distance = participant.distance + distance;
        }
    }

    // advance scene by frame
    //  1. change energy boundary
    //  2. calculate energy of all alive participant
    public entry fun advance_scene(scene: &mut Scene, ctx: &mut TxContext){
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

        let j = n -1;

        sort_participant_info(&mut all_participant);

        // Filter out participants who are too close 
        while (j >= 0) {
            let participant = vector::borrow_mut(&mut all_participant, j);
            let received = calcualte_receive_energy(participant.distance, scene.energy_source.power);
            consumed_energy = consumed_energy + received;
            if (consumed_energy > scene.energy_source.equilibrium) {
                alive_min_distance = participant.distance;
                break
            };

            participant.energy = participant.energy + received;

            vec_map::insert(&mut alive_participants, participant.id, *participant);

            if (j == 0) {
                break
            };
            j = j - 1;
        };

        // if alive_min_distance be setted. Then energy source change radius and some participant will dead.
        if (alive_min_distance != 0) {
            scene.energy_source.radius = alive_min_distance;
            scene.participants = alive_participants;
        };

        scene.parameters.frames = scene.parameters.frames - 1;
        scene.parameters.next_frame_block = tx_context::epoch(ctx) + scene.parameters.frame_interval;
    }

    // end the game, distribute reward.
    public entry fun end_scene(scene: &mut Scene, ctx: &mut TxContext){
        assert!(scene.parameters.frames == 0, E_NOT_END);
        
        let max_recevie_energy = 0;
        let n = vec_map::size(&scene.participants);
        let i = 0;
        // There may be multiple winners who receive the same amount of energy.
        let winers = vector::empty();
        while (i < n) {
            i = i + 1;
            let (key, participant) = vec_map::pop(&mut scene.participants);
            if (participant.energy < max_recevie_energy){
                continue
            };

            if (participant.energy > max_recevie_energy){
                winers = vector::empty();   
            };
            max_recevie_energy = participant.energy;
            vector::push_back(&mut winers, key);
        };

        let coin_value = coin::value(&scene.total_stake);
        
        let i = 0;
        let n = vector::length(&winers);
        let reward = coin_value / n;

        while( i < n){
            let reward_coin = coin::split(&mut scene.total_stake, reward, ctx);
            transfer::transfer(reward_coin, *vector::borrow(&winers, i));
            i = i + 1;
        }
    }

    fun calcualte_receive_energy(distance: u64, energy_intensity: u64): u64{
        if (distance == 0){
            return 0
        };
        energy_intensity / distance
    }

    //  quick sort. should be iterative version ?
    fun sort_participant_info(v: &mut vector<ParticipantInfo>){
        let right = vector::length(v) - 1;
        quick_sort(v, 0, right)
    } 

    fun quick_sort(v: &mut vector<ParticipantInfo>, left: u64, right: u64){
        if (left < right){
            let partition_index = partion(v, left, right);
            if (partition_index > 1){
                quick_sort(v, left, partition_index -1);
            };
            quick_sort(v, partition_index + 1, right);
        }
    }

    fun partion(v: &mut vector<ParticipantInfo>, left: u64, right: u64) : u64{
        let pivot: u64 = left;
        let index: u64 = pivot + 1;
        let i: u64 = index;
        
        while (i <= right) {
            if (vector::borrow(v, i).distance < vector::borrow(v, pivot).distance){
                vector::swap(v, i, index);
                index = index + 1;
            };

            i = i + 1;
        };

        vector::swap(v, pivot, index -1);
        index - 1
    }

    #[test]
    fun create_scene_test(){
        use sui::test_scenario;

        let admin = @0x1232;
        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        {
            let source = EnergySource{
                power: 100000,
                radius: 2000,
                equilibrium: 10000,
            };

            let sp = SceneParams{
                frames: 32,
                frame_interval: 10,
                next_frame_block: 10,
                max_participant: 100,
            };

            create_scene(
                source.power,
                source.radius,
                source.equilibrium,
                sp.frames,
                sp.frame_interval,
                sp.next_frame_block,
                sp.max_participant,
                2000000,
                test_scenario::ctx(scenario),
            );
        };

        test_scenario::next_tx(scenario, admin);
        // check init scene
        {
            let scene = test_scenario::take_from_sender<Scene>(scenario);
            assert!(scene.min_stake == 2000000, 0);

            assert!(scene.energy_source.power == 100000, 1);
            assert!(scene.energy_source.radius == 2000, 2);
            assert!(scene.energy_source.equilibrium == 10000, 3);

            assert!(scene.parameters.frames == 32, 4);
            assert!(scene.parameters.frame_interval == 10, 5);
            assert!(scene.parameters.next_frame_block == 10, 6);
            assert!(scene.parameters.max_participant == 100, 7);

            assert!(coin::value(&scene.total_stake) == 0, 8);

            test_scenario::return_to_sender(scenario, scene);
        };

        test_scenario::end(scenario_val);
    }

    #[test_only]
    fun create_test_scene(
        ctx: &mut TxContext,   
    ){
        let source = EnergySource{
            power: 100000,
            radius: 2000,
            equilibrium: 90,
        };

        let sp = SceneParams{
            frames: 1,
            frame_interval: 1,
            next_frame_block: 10,
            max_participant: 10,
        };
        
        create_scene(
            source.power,
            source.radius,
            source.equilibrium,
            sp.frames,
            sp.frame_interval,
            sp.next_frame_block,
            sp.max_participant,
            2000000,
            ctx,
        );
    }    

    #[test]
    fun participant_enter_move_test(){
        use sui::test_scenario;
        use sui::vec_map::{Self};
        use expansion::xcoin::{XCOIN};

        let admin = @0x1231;
        let player1 = @0x1232;
        let player2 = @0x1233;

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        create_test_scene(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, admin);

        {
            let coin = coin::mint_for_testing<XCOIN>(2000000, test_scenario::ctx(scenario));
            let scene = test_scenario::take_from_sender<Scene>(scenario);
            
            participant_enter(
                &mut scene,
                coin,
                player1,
                test_scenario::ctx(scenario),
            );

            let coin2 = coin::mint_for_testing<XCOIN>(2000000, test_scenario::ctx(scenario));
            participant_enter(
                &mut scene,
                coin2,
                player2,
                test_scenario::ctx(scenario),
            );

            assert!(vec_map::size(&scene.participants) == 2, 0);
            let player1_info = vec_map::get(&scene.participants, &player1);
            assert!(player1_info.alive == true, 1);
            assert!(player1_info.id == @0x1232, 2);
            assert!(player1_info.energy == 0, 3);
            assert!(player1_info.distance == 4000, 4);

            test_scenario::return_to_sender(scenario, scene);
        };

        // player move
        test_scenario::next_tx(scenario, admin);
        {
            let scene = test_scenario::take_from_sender<Scene>(scenario);
            participant_move(
                &mut scene,
                player2,
                1000,
                false,
                test_scenario::ctx(scenario),
            );

            let player2_info = vec_map::get(&scene.participants, &player2);
            assert!(player2_info.alive == true, 5);
            assert!(player2_info.energy == 0, 6);
            assert!(player2_info.distance == 5000, 7);

            test_scenario::return_to_sender(scenario, scene);
        };

        test_scenario::end(scenario_val);        
    }

    #[test_only]
    fun player_enter(ctx: &mut TxContext,scene: &mut Scene, players: &vector<address>){
        let i = 0;
        let n = vector::length(players);
        while (i < n){
            let coin = coin::mint_for_testing<XCOIN>(2000000, ctx);
            let player_address = vector::borrow(players, i);

            participant_enter(
                scene,
                coin,
                *player_address,
                ctx,
            );

            i = i + 1;
        }
    }

    #[test_only]
    fun player_move(ctx: &mut TxContext, scene: &mut Scene, players: &vector<address>, distance: &vector<u64>, dir: &vector<bool>){
        
        let i = 0;
        let n = vector::length(players);

        while (i < n){
            let player_address = vector::borrow(players, i);
            let distance = vector::borrow(distance, i);
            let forward  = vector::borrow(dir, i);

            participant_move(
                scene,
                *player_address,
                *distance,
                *forward,
                ctx,
            );

            i = i + 1;
        }
    }

    #[test_only]
    fun advance_epoch(ctx: &mut TxContext, n: u64){
        let i = 0;
        while(i < n ){
            tx_context::increment_epoch_number(ctx);
            i = i + 1;
        };
    }

    #[test]
    fun advance_scene_test(){
        use sui::test_scenario;
        use sui::vec_map::Self;

        let admin = @0x1231;
        let players = vector[ @0x1232, @0x1233, @0x1234, @0x1235, @0x1236, @0x1237];

        let scenario_val = test_scenario::begin(admin);
        let scenario = &mut scenario_val;

        create_test_scene(test_scenario::ctx(scenario));
        test_scenario::next_tx(scenario, admin);
        {
            let scene = test_scenario::take_from_sender<Scene>(scenario);
            player_enter(test_scenario::ctx(scenario), &mut scene, &players);
            test_scenario::return_to_sender(scenario, scene);
        };
        test_scenario::next_tx(scenario, admin);

        let move_distance = vector[ 1000, 2000, 3000, 1000, 2000, 4000];
        let forward = vector[ true, true, true, false, false, true];

        {
            let scene = test_scenario::take_from_sender<Scene>(scenario);
            player_move(test_scenario::ctx(scenario), &mut scene, &players, &move_distance, &forward);
            test_scenario::return_to_sender(scenario, scene);
        };

        test_scenario::next_tx(scenario, admin);
        {
            let scene = test_scenario::take_from_sender<Scene>(scenario);
            let ctx = test_scenario::ctx(scenario);
            advance_epoch(ctx, 10);
            advance_scene(&mut scene, ctx,);
            test_scenario::return_to_sender(scenario, scene);
        };
        test_scenario::next_tx(scenario, admin);
        {
            let scene = test_scenario::take_from_sender<Scene>(scenario);
            assert!(scene.energy_source.radius == 2000, 1);
            assert!(vec_map::size(&scene.participants) == 3, 1);
            assert!(vec_map::get(&scene.participants, &@0x1232).energy == 33, 2);
            test_scenario::return_to_sender(scenario, scene);
        };

        // end game
        test_scenario::next_tx(scenario, admin);
        {
            let scene = test_scenario::take_from_sender<Scene>(scenario);
            let ctx = test_scenario::ctx(scenario);
            end_scene(&mut scene, ctx);
            test_scenario::return_to_sender(scenario, scene);
        };

        // check reward
        test_scenario::next_tx(scenario, admin);
        {
            let winner_coin = test_scenario::take_from_address<Coin<XCOIN>>(scenario, @0x1232);
            let winner_coin_value = coin::value(&winner_coin);
            assert!(winner_coin_value == 12000000, 3);
            
            test_scenario::return_to_address(@0x1232, winner_coin);
        };

        test_scenario::end(scenario_val);  
    }
}