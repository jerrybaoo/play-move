// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

// The object container can store a series of objects, and the user 
// can identify the type of the object by u64. The stored objects are 
// indexed by incremental u64. 

module object_container::container{
    use std::vector::{Self};
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field::{Self};
    use sui::transfer;

    struct ObjectContainer has key{
        id: UID,
        field_types: vector<u64>,
        next_field_index: u64,
    }

    public fun create(ctx: &mut TxContext){
        transfer::transfer(
            ObjectContainer{
                id: object::new(ctx),
                field_types: vector::empty(),
                next_field_index: 0,
            },
            tx_context::sender(ctx),
        )
    }

    public fun length(oc: &ObjectContainer): u64{
        oc.next_field_index - 1
    }

    public fun get_type(oc: &ObjectContainer, index: u64): u64{
        *vector::borrow(&oc.field_types, index)
    }

    public fun add_object<T: key + store>(
        object_container: &mut ObjectContainer,
        object: T,
        object_type: u64,
        _ctx: &mut TxContext
    ){
        let cur_field_index = object_container.next_field_index;
        object_container.next_field_index = object_container.next_field_index + 1;

        vector::push_back(&mut object_container.field_types, object_type);
        dynamic_object_field::add(&mut object_container.id, cur_field_index, object);
    }

    public fun borrow_mut<Value: key + store>(
        oc: &mut ObjectContainer,
        index: u64,
        _ctx: &mut TxContext
    ):&mut Value {
        dynamic_object_field::borrow_mut<u64, Value>(&mut oc.id, index)
    }

    public fun borrow<Value: key + store>(
        oc: &ObjectContainer,
        index: u64,
        _ctx: &mut TxContext
    ):&Value {
        dynamic_object_field::borrow<u64, Value>(&oc.id, index)
    }
}