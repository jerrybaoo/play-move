# Overview

```
module Node{
    struct parallel{
        uid,
        nodes: vec<action_node<move_action>>
    }

    fn drive(parallel){
        for n in parallel.nodes{
            n.do() // in static lanague like move, it's not possible

            // should have small action
            if n.typeid == move_action.typeid{
                move(n)
            }else if n.typeid == stop_action.typeid{
                stop(id)
            }else{
                .......
            }
        }
    }

    struct action_node<T>{
        uid,
        value: T,
    }

    struct move_action{
        ...
    }

    struct stop_action{
        ...
    }

    // in dynamic language
    //impl Do for move_action{
    //    do()
    //}
    //impl DO for stop_action{
    //    do()
    //}
}

```
