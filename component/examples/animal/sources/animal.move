// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

// Define animals used in driver script. 

module animal::animals{
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;


    struct Animal<T: store> has key, store{
        id: UID,
        value: T,
    }    

    struct Mammal has store{
        drive_count: u64,
    }

    struct Bird has  store{
        drive_count: u64,
    }

    struct Reptile has store{
        drive_count: u64,
    }

    public fun create_mammal(ctx: &mut TxContext){
        transfer::transfer(
            Animal<Mammal>{
                id: object::new(ctx),
                value: Mammal{
                    drive_count: 0,
                }
            },
            tx_context::sender(ctx),
        )
    }

    public fun create_bird(ctx: &mut TxContext){
        transfer::transfer(
            Animal<Bird>{
                id: object::new(ctx),
                value: Bird{
                    drive_count: 0,
                }
            },
            tx_context::sender(ctx),
        )
    }

    public fun create_reptile(ctx: &mut TxContext){
        transfer::transfer(
            Animal<Reptile>{
                id: object::new(ctx),
                value: Reptile{
                    drive_count: 0,
                }    
            },
            tx_context::sender(ctx),
        )
    }

    public entry fun drive_mammal(m: &mut Animal<Mammal>){
        m.value.drive_count = m.value.drive_count;
    }

    public entry fun drive_bird(b: &mut Animal<Bird>){
        b.value.drive_count = b.value.drive_count + 1;
    }

    public entry fun drive_reptile(r: &mut Animal<Reptile>){
        r.value.drive_count = r.value.drive_count + 1;
    }
}