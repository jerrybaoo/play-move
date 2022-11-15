// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

// The object container can store a series of objects.
// Users can easily traverse it.

module object_container::container{
    use std::vector::{Self};
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::dynamic_object_field::{Self};
    use sui::vec_map::{Self, VecMap};
    use sui::transfer;

    struct EmptyValue has copy, drop, store{}

    struct ObjectContainer<Type: copy + store + drop> has key{
        id: UID,
        types: vector<Type>,
        removed_index: VecMap<u64, EmptyValue>,
        object_index: u64,
    }

    public fun create<Type: copy + store + drop>(ctx: &mut TxContext){
        transfer::transfer(
            ObjectContainer<Type>{
                id: object::new(ctx),
                types: vector::empty(),
                removed_index: vec_map::empty(),
                object_index: 0,
            },
            tx_context::sender(ctx),
        )
    }

    public fun length<Type: copy + store + drop>(oc: &ObjectContainer<Type>): u64{
        oc.object_index - vec_map::size<u64, EmptyValue>(&oc.removed_index)
    }

    public fun get_type<Type: copy + store + drop>(oc: &ObjectContainer<Type>, index: u64): Type{
        *vector::borrow(&oc.types, index)
    }

    // Add obejct to the container. The object will become the field of the container 
    // with a u64 value as key. 
    public fun add_object<Type: copy + store + drop, T: key + store>(
        oc: &mut ObjectContainer<Type>,
        object: T,
        object_type: Type,
        _ctx: &mut TxContext
    ){
        let cur_field_index: u64;

        // if the removed_index of this container is not empty, 
        // then choice one value form it as filed key of the added object
        if (vec_map::is_empty(&oc.removed_index)){
            cur_field_index = oc.object_index;
            oc.object_index = oc.object_index + 1;
            
            vector::push_back(&mut oc.types, object_type);
        }else{
            (cur_field_index,_) = vec_map::pop<u64, EmptyValue>(&mut oc.removed_index);
            
            let old_type = vector::borrow_mut<Type>(&mut oc.types, cur_field_index);
            *old_type = object_type;

            vector::push_back(&mut oc.types, object_type);
        };

        dynamic_object_field::add(&mut oc.id, cur_field_index, object);
    }

    // Remove the object from the container, insert the index of object to container's `removed_index`.
    public fun remove_object<Type: copy + store + drop, T: key + store>(
        oc: &mut ObjectContainer<Type>,
        object_index: u64,
        _ctx: &mut TxContext
    ): T{
        vec_map::insert(&mut oc.removed_index, object_index, EmptyValue{});
        let removed_object = dynamic_object_field::remove<u64, T>(&mut oc.id, object_index);
        removed_object
    }

    // Check whether the object exists.
    public fun exists_<Type: copy + store + drop>(
        oc: &ObjectContainer<Type>,
        object_index: u64,
    ): bool{
        dynamic_object_field::exists_(&oc.id, object_index)
    }

    // If the object is not exist then abort. If it is necessary to check whether it exists before calling.
    public fun borrow_mut<Type: copy + store + drop, Value: key + store>(
        oc: &mut ObjectContainer<Type>,
        index: u64,
        _ctx: &mut TxContext
    ):&mut Value {
        dynamic_object_field::borrow_mut<u64, Value>(&mut oc.id, index)
    }

    // If the object is not exist then abort. If it is necessary to check whether it exists before calling.
    public fun borrow<Type: copy + store + drop, Value: key + store>(
        oc: &ObjectContainer<Type>,
        index: u64,
        _ctx: &mut TxContext
    ):&Value {
        dynamic_object_field::borrow<u64, Value>(&oc.id, index)
    }
}