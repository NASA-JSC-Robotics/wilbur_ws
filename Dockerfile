# Set desired ROS distribution, this image currently only supports jazzy.
ARG ROS_DISTRO=jazzy

# This layer grabs package manifests from the src directory for preserving rosdep installs.
# This can significantly speed up rebuilds for the base package when src contents have changed.
FROM alpine:latest AS package-manifests

# Copy in the src directory, then remove everything that isn't a manifest or an ignore file.
COPY src/ /src/
RUN find /src -type f ! -name "package.xml" ! -name "COLCON_IGNORE" -delete && \
    find /src -type d -empty -delete

# Throw away for an empty source directory
RUN mkdir -p /src

# Using the pre-compiled ROS images as the base.
FROM ros:${ROS_DISTRO} AS er4-dev-base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Starting with Ubuntu 24.04, the default Ubuntu image already contains a non-root "ubuntu" user
# with uid 1000. Our options are to delete the user and try to recreate it, or to rename it.
# Since ownership is by UID rather than by user name, renaming is not so bad.
ARG USER_UID=1000
ARG USER_GID=1000
ARG USERNAME=er4-user

# Define the install location for the developing application
ENV ER4_WS="/home/er4-user/ws"

# DEBIAN_FRONTEND is set as an ARG instead of ENV variable so it doesn't persist in the image after build
ARG DEBIAN_FRONTEND=noninteractive

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -q -y \
    bash-completion \
    ccache \
    gdb \
    gdbserver \
    git \
    ipython3 \
    nano \
    less \
    python3-colcon-clean \
    python3-colcon-common-extensions \
    python3-colcon-mixin \
    python3-pip \
    python3-rosdep \
    python3-vcstool \
    ros-${ROS_DISTRO}-rqt-action \
    ros-${ROS_DISTRO}-rqt-tf-tree \
    ros-${ROS_DISTRO}-rqt-bag \
    ros-${ROS_DISTRO}-rqt-bag-plugins \
    ros-${ROS_DISTRO}-rqt-common-plugins \
    ros-${ROS_DISTRO}-rqt-controller-manager \
    ros-${ROS_DISTRO}-rqt-dotgraph \
    ros-${ROS_DISTRO}-rqt-msg \
    ros-${ROS_DISTRO}-plotjuggler \
    ros-${ROS_DISTRO}-rqt-py-console \
    ros-${ROS_DISTRO}-rqt-service-caller \
    ros-${ROS_DISTRO}-rqt-srv \
    ros-${ROS_DISTRO}-rqt-tf-tree \
    ros-${ROS_DISTRO}-desktop \
    software-properties-common \
    terminator \
    tmux \
    vim \
    xterm \
    wget

# Add a non-root user with provided user details
RUN if id -u ${USER_UID}; then userdel -r $(id -un ${USER_UID}); fi \
    && if id -g ${USER_GID}; then groupdel $(id -gn ${USER_GID}); fi

RUN groupadd -g ${USER_GID} ${USERNAME} \
    && useradd -l -u ${USER_UID} -g ${USER_GID} --create-home -m -s /bin/bash -G sudo,adm,dialout,dip,plugdev,video ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p \
    /home/${USERNAME}/.ccache \
    /home/${USERNAME}/.colcon \
    /home/${USERNAME}/.ros \
    /home/${USERNAME}/.bash \
    ${ER4_WS}

# Setup the install directory and copy the workspace to it.
# We could alternatively copy package manifests to preserve the layer cache if the build duration becomes too onerous.
WORKDIR  ${ER4_WS}
RUN mkdir src build install log

# Copy package manifests for installing rosdeps
COPY --chown=${USERNAME}:${USERNAME} --from=package-manifests /src/ ./src

# FIXME: Move wilbur's wilbur_gz out of the way because the gazebo deps don't work on jazzy
RUN mv src/wilbur/wilbur_gz/package.xml src/wilbur/wilbur_gz/__package.xml

# Install rosdeps
# Init is unnecessary if using the ROS base image
# RUN sudo rosdep init && rosdep update --rosdistro ${ROS_DISTRO}
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    source /opt/ros/${ROS_DISTRO}/setup.bash && \
    apt-get update && \
    rosdep update && \
    rosdep install -iy --from-paths src

# Install extra ROS deps
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    apt-get install -q -y \
    ros-${ROS_DISTRO}-ros2controlcli \
    ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
    ros-${ROS_DISTRO}-rmw-fastrtps-cpp \
    python3-virtualenv

# Configure and install MuJoCo using the defaults for the MuJoCo drivers.
# We use MuJoCo in many systems so we just install the drivers in the base workspace.
# The install is CPU dependent, this works with `x86_64` and `arm64` chips, TBD on others.
ARG MUJOCO_VERSION=3.3.4
ENV MUJOCO_VERSION=${MUJOCO_VERSION}
ENV MUJOCO_DIR="/opt/mujoco/mujoco-${MUJOCO_VERSION}"
RUN mkdir -p ${MUJOCO_DIR} && sudo chown -R ${USERNAME}:${USERNAME} ${MUJOCO_DIR}
RUN CPU_ARCH=$(uname -m); \
    wget https://github.com/google-deepmind/mujoco/releases/download/${MUJOCO_VERSION}/mujoco-${MUJOCO_VERSION}-linux-${CPU_ARCH}.tar.gz && \
    tar -xzf "mujoco-${MUJOCO_VERSION}-linux-${CPU_ARCH}.tar.gz" -C $(dirname "${MUJOCO_DIR}") && \
    rm "mujoco-${MUJOCO_VERSION}-linux-${CPU_ARCH}.tar.gz"

# Copy in the remainder of the src directory
COPY src/ src/
RUN chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}

ENV VENV=/home/${USERNAME}/colcon_venv
USER ${USERNAME}
# Starting with python 3.11, pip installs need to go into a python virtualenv
# The setup here is based on the ROS2 docs at
# https://docs.ros.org/en/jazzy/How-To-Guides/Using-Python-Packages.html
# The python virtualenv will be based at ~/colcon_venv. 
# We'll set up the bashrc to use it. We want the venv to be sourced
# first, before sourcing the ROS workspace.
RUN mkdir -p ${VENV}/src \
    && cd ${VENV} \
    && virtualenv -p python3 --system-site-packages ./venv \
    && touch ./venv/COLCON_IGNORE \
    && echo 'source ${VENV}/venv/bin/activate' >> /home/${USERNAME}/.bashrc

# Install MuJoCo specific pip dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    source ${VENV}/venv/bin/activate \
    && pip install mujoco obj2mjcf

# There's no build for arm64 on linux, so just ignore failures here if that's the case
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    source ${VENV}/venv/bin/activate \
    && pip install bpy==4.0.0 --extra-index-url https://download.blender.org/pypi/ || true


# Setup colcon default mixins and add default settings
RUN colcon mixin add default \
    https://raw.githubusercontent.com/colcon/colcon-mixin-repository/master/index.yaml && \
    colcon mixin update || true
RUN colcon metadata add default  \
    https://raw.githubusercontent.com/colcon/colcon-metadata-repository/master/index.yaml && \
    colcon metadata update || true

# Fix rosdep permissions and ensure sudo while we're at it
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    sudo apt update && \
    . /opt/ros/${ROS_DISTRO}/setup.bash && \
    rosdep update --rosdistro ${ROS_DISTRO}

# For Gazebo fortress model files
ENV IGN_GAZEBO_RESOURCE_PATH=/opt/ros/${ROS_DISTRO}/share

# Setup entrypoint
# copy in configs for different features
COPY --chown=${USERNAME}:${USERNAME} config/colcon-defaults.yaml /home/${USERNAME}/.colcon/defaults.yaml
COPY --chown=${USERNAME}:${USERNAME} config/terminator_config /home/${USERNAME}/.config/terminator/config

# Setup entrypoint and ensure it's added to ~/.bashrc
COPY scripts/entrypoint.sh /entrypoint.sh
RUN echo "source /entrypoint.sh" >> ~/.bashrc

# Make it obvious when operating in a container
RUN echo "PS1=\"${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\](docker):\[\033[01;34m\]\w\[\033[00m\]\$ \"" >> ~/.bashrc

ENTRYPOINT ["/entrypoint.sh"]

# Images built in CI will have the default UID of 1000. For deployment, we'd like the user in the 
# container to match the host user. This requires customizing the setup above.
FROM er4-dev-base AS er4-dev
ARG USERNAME
ARG USER_UID
ARG USER_GID

USER root
# We first update anything in the base image to match the UID/GID specified by the build,
# the username should always stay the same as the base image. The intent here is to provide
# a way for developers to share code between the container and host, in a way that doesn't
# require any id mapping. This is only necessary for the release image which may use pre-
# compiled images where the image's user DOESN'T match the hosts (UID/GID != 1000).
#
# Additionally, Usermod does some weird shenanigans trying to change the whole host system.
# Weonly care about the users home directory, so to speed things up, just change the passwd
# and groups manaully then update the user. Further, we parallize execution of the chown
# to speed that up on host machines. Ultimate this isn't critical, because we mount the
# workspace over the source. But it is simpler and safer than piecemealing things as
# needed, it is also significantly faster than `usermod`.
RUN OLD_UID=$(id -u ${USERNAME}) && \
    OLD_GID=$(id -g ${USERNAME}) && \
    if [ "${OLD_UID}" != "${USER_UID}" ] || [ "${OLD_GID}" != "${USER_GID}" ]; then \
        sed -i "s/^\(${USERNAME}:[^:]*:\)[^:]*:[^:]*:/\1${USER_UID}:${USER_GID}:/" /etc/passwd && \
        sed -i "s/^\(${USERNAME}:[^:]*:\)[^:]*:/\1${USER_GID}:/" /etc/group && \
        find /home/${USERNAME} \
            \( -user ${OLD_UID} -o -group ${OLD_GID} \) \
            -print0 | xargs -0 -P $(nproc) -n 1000 chown ${USER_UID}:${USER_GID}; \
    fi

USER ${USERNAME}

# Source built dev image for automated testing.
FROM er4-dev-base AS er4-dev-source

ARG USERNAME

RUN . /opt/ros/${ROS_DISTRO}/setup.bash && \
    colcon build
