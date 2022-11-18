# OverView

## implement plan
1. control node 
```
    struct ControlNode{
        kind     
        child_objects
    }


    struct ActionWrapper{
        kind:
        action_object.
    }
```

2. action node
```
    action node is defined in other modules, 

```

3. script  
    script connects action node and control node. Drive the behavior tree by calling script.

    The pseudo-code look like
```
    
    func tick(root_node){
        
        control_node_stack.

        control_node_stack.push(root_node);

        loop {

            if control_node_stack.is_empty(){
                break;
            }

            let i = 0;

            op_ctl_node = control_node_stack.pop()

            while i < op_ctl_node.childs.size(){

                if op_ctl_node.childs[i] == ctl{

                    control_node_stack.push(op_ctl_node)
                    control_node_stack.push(op_ctl_node.childs[i])

                    break;

                }else if op_ctl_node.childs[i] == action{

                    let res = drive_action(op_ctl_node.childs[i]);

                    res = judge_control_node_status(op_ctl_node, res);

                    if res == success {
                        break;
                    }
                }

                i++
            }    
        }                                                       
    }                                                                                                                                                                                                                                           
```