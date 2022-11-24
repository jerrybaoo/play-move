// Copyright (c) developer.
// SPDX-License-Identifier: Apache-2.0

// Because the action node is open and no one knows how it will be invoked, 
// the behavior tree is driven in script. Because the script does not store data, 
// it can be replaced at any time.

script {
    use std::vector::{Self};
    use sui::tx_context::{TxContext};

    use behavior_tree::easy_action::{Self, Walk, Jump, Blackboard};
    use behavior_tree::node::{Self, Root, TreeNode};

    fun tick(root: &mut Root, black_board: &mut Blackboard,_ctx: &mut TxContext){
        let ctl_node_stack = vector::empty();
        let result_stack = vector::empty();

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
            // The node enters the stack first, and then each control node controls the child 
            // nodes into the stack according to its own logic.
            // If it is an action node, then execute it directly
            if (node::is_select(op_ctl_type)){
                if (!node::is_running(&op_ctl_node)){
                    node::enter(&mut op_ctl_node);
                    vector::push_back<TreeNode>(&mut ctl_node_stack, op_ctl_node);
                    while (i < op_ctl_node_child_size){
                        let child_id = node::child_id(&op_ctl_node, i);
                        let child_type = node::type(root, child_id);

                        if (!node::is_control(child_type)){
                            let action_tree_node = node::assemble_action_node(child_id, child_type);
                            vector::push_back<TreeNode>(&mut ctl_node_stack, action_tree_node);
                        };

                        i = i + 1;
                    };
                }else{
                    let j = 0;
                    let res_stack_size = vector::length(&result_stack);
                    let select_result = true;

                    while (j < res_stack_size){
                        let r = vector::pop_back(&mut result_stack);
                        if (!r){
                            select_result = false;
                        };
                        j = j +1;
                    };

                    vector::push_back(&mut result_stack, select_result);
                } 
                
            }else if (node::is_random(op_ctl_type)){
                if (!node::is_running(&op_ctl_node)){
                    node::enter(&mut op_ctl_node);
                    // Assuming a random number 0 is obtained
                    let i = 0;
                    let child_id = node::child_id(&op_ctl_node, i);

                    let child_type = node::type(root, child_id);
                    if (!node::is_control(child_type)){
                        let action_tree_node = node::assemble_action_node(child_id, child_type);
                        vector::push_back<TreeNode>(&mut ctl_node_stack, action_tree_node);
                    }
                }
                // The random control node has only one child, so we don't need to change the stack

            } else {
                // Here we need a stack to record the result of each action,
                // Then the parent node of action decides the next action based on these results
                if (easy_action::is_jump_action(op_ctl_type)){
                    let jump = node::borrow_mut_action_node<Jump>(root, node::id(&op_ctl_node));
                    let res = easy_action::jump(jump, black_board);
                    vector::push_back(&mut result_stack, res);

                }else if (easy_action::is_walk_action(op_ctl_type)){
                    let walk = node::borrow_mut_action_node<Walk>(root, node::id(&op_ctl_node));
                    let res = easy_action::walk(walk, black_board);
                    vector::push_back(&mut result_stack, res);

                }else {

                };
            };
        }
    }
}