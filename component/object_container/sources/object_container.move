// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

// The object container can store a series of objects.
// The user can set and get the type of the object. 
// The stored objects are indexed by incremental u64.

module object_container::container{
    use std::vector::{Self};
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field::{Self};
    use sui::transfer;

    struct ObjectContainer<Type: copy + store> has key{
        id: UID,
        types: vector<Type>,
        object_index: u64,
    }

    public fun create<Type: copy + store>(ctx: &mut TxContext){
        transfer::transfer(
            ObjectContainer<Type>{
                id: object::new(ctx),
                types: vector::empty(),
                object_index: 0,
            },
            tx_context::sender(ctx),
        )
    }

    public fun length<Type: copy + store>(oc: &ObjectContainer<Type>): u64{
        oc.object_index - 1
    }

    public fun get_type<Type: copy + store>(oc: &ObjectContainer<Type>, index: u64): Type{
        *vector::borrow(&oc.types, index)
    }

    public fun add_object<Type: copy + store, T: key + store>(
        object_container: &mut ObjectContainer<Type>,
        object: T,
        object_type: Type,
        _ctx: &mut TxContext
    ){
        let cur_field_index = object_container.object_index;
        object_container.object_index = object_container.object_index + 1;

        vector::push_back(&mut object_container.types, object_type);
        dynamic_object_field::add(&mut object_container.id, cur_field_index, object);
    }

    public fun borrow_mut<Type: copy + store, Value: key + store>(
        oc: &mut ObjectContainer<Type>,
        index: u64,
        _ctx: &mut TxContext
    ):&mut Value {
        dynamic_object_field::borrow_mut<u64, Value>(&mut oc.id, index)
    }

    public fun borrow<Type: copy + store, Value: key + store>(
        oc: &ObjectContainer<Type>,
        index: u64,
        _ctx: &mut TxContext
    ):&Value {
        dynamic_object_field::borrow<u64, Value>(&oc.id, index)
    }
}