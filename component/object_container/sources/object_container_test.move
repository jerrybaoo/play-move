// Copyright (c) Developer.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module object_container::container_test{
    use sui::test_scenario as ts;
    use sui::object::{Self, UID};

    use object_container::container::{Self, ObjectContainer};

    struct Object0 has key, store{
        id: UID,
        name: u64,
    }

    struct Object1 has key, store{
        id: UID,
        index : u64,
    }

    const Object0Type: u64 = 0;
    const Object1Type: u64 = 1;

    #[test]
    fun add_obejct_should_work(){
        let sender = @0x0;
        let scenario = ts::begin(sender);
        
        container::create<u64>(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, sender);
        {
            let oc = ts::take_from_sender<ObjectContainer<u64>>(&mut scenario);
            let ob1 = Object0{
                id: object::new(ts::ctx(&mut scenario)),
                name: 0,
            };

            let ob2 = Object1{
                id: object::new(ts::ctx(&mut scenario)),
                index: 1,
            };

            container::add_object<u64, Object0>(&mut oc, ob1, Object0Type, ts::ctx(&mut scenario));
            container::add_object<u64, Object1>(&mut oc, ob2, Object1Type, ts::ctx(&mut scenario));
            
            assert!(container::length(&oc) == 2, 0);

            assert!(container::get_type<u64>(&oc, 1) == Object1Type, 1);
            assert!(container::get_type<u64>(&oc, 0) == Object0Type, 2);
            
            assert!(container::exists_<u64>(&oc, 0), 3);
            assert!(container::exists_<u64>(&oc, 1), 4);
            assert!(!container::exists_<u64>(&oc, 2), 5);

            //borrow mutble
            let add_ojbect0 = container::borrow_mut<u64, Object0>(&mut oc, 0,ts::ctx(&mut scenario));
            add_ojbect0.name = 101;

            let add_ojbect1 = container::borrow_mut<u64, Object1>(&mut oc, 1, ts::ctx(&mut scenario));
            add_ojbect1.index = 1000;
            
            // after mutated
            let add_ojbect_after_mutated = container::borrow_mut<u64, Object0>(&mut oc, 0,ts::ctx(&mut scenario));
            assert!(add_ojbect_after_mutated.name == 101, 6);

            let add_ojbect1_after_mutated = container::borrow_mut<u64, Object1>(&mut oc, 1, ts::ctx(&mut scenario));
            assert!(add_ojbect1_after_mutated.index == 1000, 7);

            ts::return_to_sender(&mut scenario, oc);
        };

        ts::end(scenario);
    }

    #[test]
    fun remove_object_should_work(){
        let sender = @0x0;
        let scenario = ts::begin(sender);
        
        container::create<u64>(ts::ctx(&mut scenario));
        ts::next_tx(&mut scenario, sender);
        {
            let oc = ts::take_from_sender<ObjectContainer<u64>>(&mut scenario);
            let ob1 = Object0{
                id: object::new(ts::ctx(&mut scenario)),
                name: 0,
            };

            let ob2 = Object1{
                id: object::new(ts::ctx(&mut scenario)),
                index: 1,
            };

            container::add_object<u64, Object0>(&mut oc, ob1, Object0Type, ts::ctx(&mut scenario));
            container::add_object<u64, Object1>(&mut oc, ob2, Object1Type, ts::ctx(&mut scenario));

            let Object0{ id, name: _ } = container::remove_object<u64, Object0>(&mut oc, 0, ts::ctx(&mut scenario));
            object::delete(id);

            // check exist
            assert!(!container::exists_<u64>(&oc, 0), 3);

            // add object after remove
            let ob3 = Object0{
                id: object::new(ts::ctx(&mut scenario)),
                name: 3,
            };
            container::add_object<u64, Object0>(&mut oc, ob3, Object0Type, ts::ctx(&mut scenario));

            // check exist
            assert!(container::exists_<u64>(&oc, 0), 3);

            ts::return_to_sender(&mut scenario, oc);
        };

        ts::end(scenario);
    }
}