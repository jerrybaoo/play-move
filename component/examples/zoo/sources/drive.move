// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

// Iterate over the animal objects in the container, and drive them.

script {
    use sui::tx_context::{TxContext};
    use animal::animals::{Self, Animal, Mammal, Bird, Reptile};
    use object_container::container::{Self, ObjectContainer};   

    const MAMMAL: u64 = 0;
    const BIRD: u64 = 1;
    const REPTILE: u64 = 2;

    fun drive_animals<T: store>(
        oc: &mut ObjectContainer<u64>,
        ctx: &mut TxContext,
    ){
        let i = 0;
        let n = container::length(oc);
        while (i < n) {
            let object_type = container::get_type(oc, i);
            
            if (object_type == MAMMAL) {
                let a = container::borrow_mut<u64 ,Animal<Mammal>>(oc, i, ctx);
                animals::drive_mammal(a);
            }else if (object_type == BIRD){
                let a = container::borrow_mut<u64, Animal<Bird>>(oc, i, ctx);
                animals::drive_bird(a);
            }else if (object_type == REPTILE){
                let a = container::borrow_mut<u64, Animal<Reptile>>(oc, i, ctx);
                animals::drive_reptile(a);
            };

            i = i +1;
        }
    }
}