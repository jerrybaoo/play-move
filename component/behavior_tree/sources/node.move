// Copyright (c) developer.
// SPDX-License-Identifier: Apache-2.0

// node just store all data.
module behavior_tree::node{
    use std::vector::{Self};

    use sui::bag::{Self,Bag};
    use sui::object::{Self, UID};
    use sui::tx_context::{TxContext};

    // node type    
    const ACTION: u64 = 0;
    const SELECT: u64 = 1;
    const RANDOM: u64 = 1;

    //error
    const ERROR_NOT_CONTROL:u64 = 0;

    // The root node object.
    struct Root has key, store{
        id: UID,
        
        // used to reflect data from bags
        node_types: vector<u64>,
        // control node(TreeNode) + action_node(external),
        nodes: Bag,
    }

    // Action node just has one child.
    struct TreeNode has copy, store, drop{
        id: u64,
        parent_id: u64,
        kind: u64,
        childs: vector<u64>,
    }

    public fun create(kind: u64, ctx: &mut TxContext): Root{
        let root = Root{
            id: object::new(ctx),
            node_types: vector::empty(),
            nodes: bag::new(ctx),
        };

        let root_node = TreeNode{
            id: 0,
            parent_id: 0,
            kind: kind,
            childs: vector::empty(),
        };

        bag::add(&mut root.nodes, root_node.id, root_node);
        vector::push_back(&mut root.node_types, kind);

        root
    }

    public entry fun add_control_node(root: &mut Root, control_kind: u64, parent_id: u64,){
        let next_node_id = vector::length(&root.node_types) + 1;
        let control_node = TreeNode{
            id: next_node_id,
            parent_id: parent_id,
            kind: control_kind,
            childs: vector::empty(),
        };

        let parent_node_type = vector::borrow(&root.node_types, parent_id);
        assert!(is_control(*parent_node_type), ERROR_NOT_CONTROL);

        let parent_node = borrow_mut_control_node(root, parent_id);
        vector::push_back(&mut parent_node.childs, next_node_id);

        bag::add(&mut root.nodes, control_node.id, control_node);
        vector::push_back(&mut root.node_types, control_kind);
    }

    public entry fun add_action_node<Action: copy + store>(root: &mut Root, action_kind: u64, parent_id: u64, action: Action){
        let next_node_id = vector::length(&root.node_types) + 1;

        let parent_node_type = vector::borrow(&root.node_types, parent_id);
        
        assert!(is_control(*parent_node_type), ERROR_NOT_CONTROL);

        let parent_node = borrow_mut_control_node(root, parent_id);
        vector::push_back(&mut parent_node.childs, next_node_id);

        bag::add(&mut root.nodes, next_node_id, action);
        vector::push_back(&mut root.node_types, action_kind);
    }

    public fun is_control(node_type: u64): bool{
        is_select(node_type) || is_random(node_type)
    }

    public fun is_select(node_type: u64): bool{
        node_type == SELECT
    }

    public fun is_random(node_type: u64): bool{
        node_type == RANDOM
    }

    public fun borrow_mut_control_node(root: &mut Root, id: u64): &mut TreeNode{
        bag::borrow_mut<u64, TreeNode>(&mut root.nodes, id)
    }

    public fun borrow_mut_action_node<Action: store>(root: &mut Root, id: u64): &mut Action{
        bag::borrow_mut<u64, Action>(&mut root.nodes, id)
    }

    public fun type(root: &Root, id: u64): u64{
        *vector::borrow(&root.node_types, id)
    }

    public fun id(node: &TreeNode): u64{
        node.id
    }

    public fun child_length(node: &TreeNode): u64{
        vector::length(&node.childs)
    }

    public fun child_id(node: &TreeNode, child_index: u64): u64{
        *vector::borrow(&node.childs, child_index)
    }

    public fun assemble_action_node(id: u64, kind: u64): TreeNode{
        TreeNode{
            id: id,
            parent_id: 0,
            kind: kind,
            childs: vector::empty(),
        }
    }    
}