#!/bin/bash

# robot specific
alias reset_gripper='ros2 control set_controller_state robotiq_activation_controller active;ros2 control set_controller_state robotiq_gripper_hande_controller active;ros2 service call /robotiq_activation_controller/reactivate_gripper std_srvs/srv/Trigger {}'

# ros helpful
alias clean_workspace='rm -rf build/* install/* log/* ' # this will keep only the .gitkeep files
alias check_it='rosdep check --from-paths . -i --rosdistro "$ROS_DISTRO"'
alias rosdep_it='rosdep install --from-paths . -i -y --rosdistro "$ROS_DISTRO"'
