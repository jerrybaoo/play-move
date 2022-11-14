// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

// The demo wants to practice the traditional OO programming paradigm in move.
// Since move is a completely static language, this demo may not be a best practice.

// The Zoo has many animal. The zoo owner can add a lot kind of animals and then drive them.
// Each animal have unique behaviors.

module zoo_demo::zoo{
    use std::vector::{Self};
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field::{Self};
    use sui::transfer;

    struct Zoo has key{
        id: UID,
        field_types: vector<u64>,
        next_field_index: u64,
    }

    const DOG: u64 = 0;
    const BIRD: u64 = 1;

    struct Dog has key, store{
        id: UID,
        legs: u64,
        count: u64,
    }

    struct Bird has key, store{
        id: UID,
        legs: u64,
        wings: u64,
        count: u64,
    }

    public entry fun create_zoo(ctx: &mut TxContext){
        transfer::transfer(
            Zoo{
                id: object::new(ctx),
                field_types: vector::empty(),
                next_field_index: 0,
            },
            tx_context::sender(ctx),
        )
    }

    public entry fun add_animal<T: key + store>(
        zoo: &mut Zoo,
        object: T,
        object_type: u64,
        _ctx: &mut TxContext
    ){
        let cur_field_index = zoo.next_field_index;
        zoo.next_field_index = zoo.next_field_index + 1;

        vector::push_back(&mut zoo.field_types, object_type);
        dynamic_object_field::add(&mut zoo.id, cur_field_index, object);
    }

    public entry fun drive_animals(
        zoo: &mut Zoo,
        _ctx: &mut TxContext,
    ){
        let i = 0; 
        while(i < zoo.next_field_index){
            let type = *vector::borrow(&zoo.field_types, i);

            if (type == DOG){
                let dog = dynamic_object_field::borrow_mut<u64, Dog>(&mut zoo.id, i);
                drive_dog(dog);
            }else if (type == BIRD){
                let bird = dynamic_object_field::borrow_mut<u64, Bird>(&mut zoo.id, i);
                drive_bird(bird);
            }else{
                assert!(false, 1);
            };

            i = i + 1;
        }
    }

    public entry fun drive_dog(
        dog: &mut Dog,
    ){
        dog.count = dog.count + 1;
    }

    public entry fun drive_bird(
        bird: &mut Bird
    ){
        bird.count = bird.count + 2;
    }

    #[test]
    fun test_drive_object(){
        use sui::test_scenario as ts;
        let sender = @0x0;
        let scenario = ts::begin(sender);
        {
            create_zoo(ts::ctx(&mut scenario));
        };

        // add animal to zoo
        ts::next_tx(&mut scenario, sender);
        {
            let zoo = ts::take_from_sender<Zoo>(&mut scenario);
            assert!(zoo.next_field_index == 0, 0);

            let dog = Dog{
                id: ts::new_object(&mut scenario),
                legs:  4,
                count: 0,
            };

            let bird = Bird {
                id: ts::new_object(&mut scenario),
                legs:  2,
                wings: 2,
                count: 0,
            };

            add_animal(&mut zoo, dog, DOG, ts::ctx(&mut scenario));                
            add_animal(&mut zoo, bird, BIRD, ts::ctx(&mut scenario));                

            ts::return_to_sender(&mut scenario, zoo);
        };

        // drive all animals in zoo
        ts::next_tx(&mut scenario, sender);
        {
            let zoo = ts::take_from_sender<Zoo>(&mut scenario);
            assert!(zoo.next_field_index == 2, 1);

            drive_animals(&mut zoo, ts::ctx(&mut scenario));

            ts::return_to_sender(&mut scenario, zoo);
        };

        // check the state of animas after drive.
        ts::next_tx(&mut scenario, sender);
        {
            let zoo = ts::take_from_sender<Zoo>(&mut scenario);
            
            let dog = dynamic_object_field::borrow<u64, Dog>(&mut zoo.id, 0);
            assert!(dog.count == 1, 2);

            let bird = dynamic_object_field::borrow<u64, Bird>(&mut zoo.id, 1);
            assert!(bird.count == 2, 3);

            ts::return_to_sender(&mut scenario, zoo);
        };

        ts::end(scenario); 
    }
}