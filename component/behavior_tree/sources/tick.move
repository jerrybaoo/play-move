// Copyright (c) developer.
// SPDX-License-Identifier: Apache-2.0

// Because the action node is open and no one knows how it will be invoked, 
// the behavior tree is driven in script. Because the script does not store data, 
// it can be replaced at any time.

script {
    use std::vector::{Self};
    use sui::tx_context::{TxContext};

    use behavior_tree::node::{Self, Root, TreeNode};

    fun tick(root: &mut Root, _ctx: &mut TxContext){
        let ctl_node_stack = vector::empty();

        let root_node = node::borrow_mut_control_node(root, 0);
        vector::push_back<TreeNode>(&mut ctl_node_stack, *root_node);

        loop{
            if (vector::length(&ctl_node_stack) == 0){
                break
            };
            
            let i = 0;
            let op_ctl_node = vector::pop_back<TreeNode>(&mut ctl_node_stack);
            let op_ctl_node_child_size = node::child_length(&op_ctl_node);

            let op_ctl_type = node::type(root, node::id(&op_ctl_node));
            if (node::is_select(op_ctl_type)){
                vector::push_back<TreeNode>(&mut ctl_node_stack, op_ctl_node);
                while (i < op_ctl_node_child_size){
                    let child_id = node::child_id(&op_ctl_node, i);
                    let child_type = node::type(root, child_id);

                    if (!node::is_control(child_type)){
                        let action_tree_node = node::assemble_action_node(child_id, child_type);
                        vector::push_back<TreeNode>(&mut ctl_node_stack, action_tree_node);
                    };

                    i = i + 1;
                }

            }else if (node::is_random(op_ctl_type)){
                let i = 0;
                let child_id = node::child_id(&op_ctl_node, i);
                
                let child_type = node::type(root, child_id);
                if (!node::is_control(child_type)){
                    let action_tree_node = node::assemble_action_node(child_id, child_type);
                    vector::push_back<TreeNode>(&mut ctl_node_stack, action_tree_node);
                }
            } else {
                // do action
                //borrow_mut_action_node<SOMEACTION>(root, node::id(op_ctl_node))
            };
        }
    }
}