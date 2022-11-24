// Copyright (c) developer.
// SPDX-License-Identifier: Apache-2.0

// Simple action for demonstration

module behavior_tree::easy_action{
    const WALK_ACTION: u64 = 5;
    const JUMP_ACTION: u64 = 6;
    
    struct Blackboard has copy, store{
        x_point: u64,
        y_point: u64,
    }

    struct Walk has copy, store{
        speed: u64,
    }

    struct Jump has copy, store{
        high: u64,
    }

    public fun walk(walk: &Walk, black_board: &mut Blackboard):bool{
        black_board.x_point = black_board.x_point + walk.speed;
        true
    }

    public fun jump(jump: &Jump, black_board: &mut Blackboard):bool{
        black_board.y_point = black_board.y_point + jump.high;
        true
    }

    public fun is_jump_action(action_type: u64): bool{
        action_type == JUMP_ACTION
    }

    public fun is_walk_action(action_type: u64): bool{
        action_type == WALK_ACTION
    }
}