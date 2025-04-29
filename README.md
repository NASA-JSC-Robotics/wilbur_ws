# WilbUR Workspace

Workspace for containerized development with the WilbUR robot (Warthog and UR10e).

## Running Wilbury things

To run Wilbur with `mock_hardware` and a single controller manager:

```bash
# Launches the mock hardware simulated controller interface
ros2 launch wilbur_deploy control_mock_hardware.launch.py

# Starts moveit and opens and rviz window for planning and execution
ros2 launch wilbur_moveit_config wilbur_moveit.launch.py
```

For the LUCCI demonstration, we can split the controller managers and run one for the warthog and one for the UR.
This allows us to launch controller managers in a potentially distributed manner on multiple PCs.
This is to test running the HSPC as the control computer for either robot.

Note that in this case, you must change the controller name in `wilbur_moveit_config/config/moveit_controllers.yaml` from `joint_trajectory_controller` to `/ur/joint_trajectory_controller` for moveit to execute plans in this version.
This is because we are still including UR launch files, which do not support spawning controllers in the way we need to.

To run Wilbur with `mock_hardware` and one controller manager for the warthog and one controller manager for the UR:

```bash
# Launches the warthog only
ros2 launch wilbur_deploy control_mock_hardware.launch.py separate_controls_pcs:=true

# Launches the namespace UR only
ros2 launch wilbur_deploy control_mock_hardware.launch.py separate_controls_pcs:=true launch_ur:=true

# Starts moveit and opens and rviz window for planning and execution
# NOTE: Refer to the README in wilbur_deploy for any caveats here, this may not work out of the box.
ros2 launch wilbur_moveit_config wilbur_moveit.launch.py
```

Run Wilbur with in ignition.
This should launch ignition with all of the necessary components.

```bash
ros2 launch wilbur_gz sim_gz.launch.py
ros2 launch wilbur_moveit_config wilbur_moveit.launch.py sim_ignition:=true

# make the warthog drive forward!
ros2 topic pub /cmd_vel_unstamped geometry_msgs/msg/Twist "{linear: {x: 1.0}}" -r 5
```

*NOTE:* Ogre2 rendering may have issues in VMs on mac for Gazebo.
This can be addressed either by changing the rendering (hard) or just by running with software:

```bash
# Use CPU for rendering, it might be slow but it should work
LIBGL_ALWAYS_SOFTWARE=1 ros2 launch wilbur_gz sim_gz.launch.py
```

## Quick Development Setup

1) [Install Docker](https://docs.docker.com/engine/install/ubuntu/)
    - Don't worry about Docker Desktop
    - For Ubuntu recommend using the [utility script](https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script)
2) Clone this repo with submodules by including the recursive option

    ```bash
    git clone --recursive git@js-er-code.jsc.nasa.gov:imetro/robots/wilbur/wilbur-ws.git
    ```

3) If not cloned with submodules, update with

    ```bash
    git submodule update --init
    ```

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
  - *NOTE:* Images are tagged based on the repo's name/location and either the tag or branch of an MR.
