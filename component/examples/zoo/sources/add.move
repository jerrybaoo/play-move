// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

// Add the animal objects to object container.

script {
    use sui::tx_context::{TxContext};
    use animal::animals::{Animal};
    use object_container::container::{Self, ObjectContainer};   

    fun add_animal<T: store>(
        oc: &mut ObjectContainer<u64>,
        animal: Animal<T>,
        animal_type: u64,
        ctx: &mut TxContext,
    ){
        container::add_object<u64, Animal<T>>(oc, animal, animal_type, ctx);
    }
}