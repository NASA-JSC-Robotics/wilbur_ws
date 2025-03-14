# WilbUR Workspace

Workspace for containerized development with the WilbUR robot (Warthog and UR10e).

## Running Wilbury things

*Note - I don't know why I cant use the iMarker in Rviz for mock_hardware versions. You can still change the joints from the joints tab of the MotionPlanning panel, and it will work as expected. The iMarker does work for gazebo things.

Run Wilbur with `mock_hardware` implemented with just one controller manager to display in Rviz 
```bash
ros2 launch wilbur_deploy control_mock_hardware.launch.py 
ros2 launch wilbur_moveit_config wilbur_moveit.launch.py
```

Run Wilbur with `mock_hardware` implemented with one controller manager for the warthog and one controller manager for the UR.
This is to test for when we have HPSC running the UR alone. Note that for sim, we are still launching the UR launch files, so those will need to be separated in the future. Note that in this case, you must change the controller name in `wilbur_moveit_config/config/moveit_controllers.yaml` from `joint_trajectory_controller` to `/ur/joint_trajectory_controller` for moveit to execute plans in this version.
```bash
ros2 launch wilbur_deploy control_mock_hardware.launch.py separate_controls_pcs:=true
ros2 launch wilbur_moveit_config wilbur_moveit.launch.py
```

Run Wilbur with in ignition. This should launch ignition with all of the necessary components.
```bash
ros2 launch wilbur_gz sim_gz.launch.py
ros2 launch wilbur_moveit_config wilbur_moveit.launch.py sim_ignition:=true

# make the warthog drive forward!
ros2 topic pub /cmd_vel_unstamped geometry_msgs/msg/Twist "{linear: {x: 1.0}}" -r 5
```

## Quick Development Setup

1) [Install Docker](https://docs.docker.com/engine/install/ubuntu/)
    - Don't worry about Docker Desktop
    - For Ubuntu recommend using the [utility script](https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script)
2) Fork or copy the contents of this repository as needed
3) Setup your source code for the `src/` directory
    - Either with git submodules (`git submodule add ...`)
    - Or with a repos file and vcs tool  (`vcs import ...`)
4) Set your user information for the project build
    - We recommend just putting this in your `~/.bashrc`:

      ```bash
      export USER_UID=$(id -u $USER)
      export USER_GID=$(id -g $USER)
      ```

    - Alternatively, open the `.env` file in the root of this repo and update each line with your information
        - `USER_UID` and `USER_GID`
            - found using `id -u` and `id -g` respectively

## Using the Images

Build the base images using the compose specification.

To build the development image from the repo root, and then launch it

```bash
# Compile the image
docker compose build

# Start it
docker compose up dev -d

# Connect to the console
docker compose exec dev bash
```

Once you're attached to the container, you can use it as a regular colcon workspace.
The contents of the `src/` directory will be mounted into `/home/er4-user/ws/src`.

### Launching the Wilbur Simulations

For more information refer to the [wilbur_deploy README](src/wilbur/wilbur_deploy/README.md).

### Other Things to Note

- Build logs, compiled artifaces, and the `.ccache` are also mounted in the workspace/user home.
This ensure artifacts are persisted even when restarting or recreating the container.

- Your host's DDS configuration (either cyclone or fastrtps) will be mounted into the image if set in your environment.
For more information refer to the [compose specification](docker-compose.yaml).

- Defaults for `colcon build` are set for the user. To change or modify, refer to the [defaults file](config/colcon-defaults.yaml).

- Two samples for GitLab CI for either [git submodules](.gitlab-ci.yml.submodules) or [vcs workspace](gitlab-ci.yml.vcs) are included.
Depending on your workflow, pick on and move it to `.gitlab-ci.yml` and it should build and push images, and run tests.
  - *NOTE:* There MUST be a `project.repos` file in the repo root to work with the VCS CI template.
