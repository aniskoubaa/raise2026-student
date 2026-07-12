# Author: Prof. Anis Koubaa <anis.koubaa@gmail.com>
# RAISE 2026 — ROS 2 Jazzy + Gazebo Harmonic
# Base: osrf/ros:jazzy-desktop (bundles ros_gz → Gazebo Harmonic).

ARG ROS_DISTRO=jazzy
FROM osrf/ros:${ROS_DISTRO}-desktop

ARG ROS_DISTRO=jazzy
ARG HOST_UID=1000
ARG HOST_GID=1000
ARG USERNAME=raise

ENV DEBIAN_FRONTEND=noninteractive

# Upstream ROS 2 / Gazebo deps. Installed at build time so first-boot is fast.
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3-colcon-common-extensions \
      python3-rosdep \
      python3-vcstool \
      python3-pip \
      ros-${ROS_DISTRO}-ros-gz \
      ros-${ROS_DISTRO}-ros-gz-bridge \
      ros-${ROS_DISTRO}-ros-gz-sim \
      ros-${ROS_DISTRO}-clearpath-simulator \
      ros-${ROS_DISTRO}-ur-description \
      ros-${ROS_DISTRO}-realsense2-description \
      ros-${ROS_DISTRO}-robotiq-description \
      ros-${ROS_DISTRO}-nav2-bringup \
      ros-${ROS_DISTRO}-xacro \
      ros-${ROS_DISTRO}-robot-state-publisher \
      ros-${ROS_DISTRO}-cv-bridge \
      python3-opencv \
      python3-flask \
      mesa-utils \
      sudo \
      xauth \
   && rm -rf /var/lib/apt/lists/*

# Pip deps for labs 08-09 (no ROS apt package exists for these).
#
# Pin numpy<2 IN THE SAME pip resolve as ultralytics. Pinning it in a *later*
# command fails: `pip install ultralytics` first resolves numpy->2.x and tries to
# uninstall the base image's apt numpy 1.26.4, which has no RECORD file ->
# "ERROR: Cannot uninstall numpy 1.26.4". Constraining numpy<2 up front keeps the
# apt numpy in place (cv_bridge is built against numpy 1.x).
#
# --extra-index-url pulls the CPU build of torch: "torch==X+cpu" sorts ABOVE the
# plain CUDA wheel (PEP 440 local version), so pip picks it and skips ~2.5 GB of
# nvidia-* CUDA wheels we don't need here -- YOLO runs on CPU and the VLM is a
# remote API (the GPU, when present, is for Gazebo rendering, not torch).
#
# Wrapped in a 3-attempt retry loop: these are large downloads and flaky networks
# can drop a TLS record mid-stream ("SSL: DECRYPTION_FAILED_OR_BAD_RECORD_MAC"),
# which pip's own retries don't always recover. The loop re-runs the whole install.
RUN for attempt in 1 2 3; do \
      python3 -m pip install --no-cache-dir --break-system-packages \
        --retries 5 --timeout 120 \
        --extra-index-url https://download.pytorch.org/whl/cpu \
        "numpy<2" torch torchvision ultralytics openai && break; \
      echo "[pip] attempt $attempt failed (transient network?) -- retrying in 10s"; \
      sleep 10; \
      [ "$attempt" = 3 ] && exit 1; \
    done

# Ubuntu 24.04 base ships with a default `ubuntu` user at UID 1000.
# Drop it, then create our user at the host's UID/GID so volume writes are
# owned by the host user (not root, not "ubuntu").
RUN userdel -r ubuntu 2>/dev/null || true \
 && groupadd -g ${HOST_GID} ${USERNAME} \
 && useradd -m -u ${HOST_UID} -g ${HOST_GID} -s /bin/bash -G sudo ${USERNAME} \
 && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME}

USER ${USERNAME}
WORKDIR /raise_ros2_ws

# Source ROS + workspace overlay in interactive shells
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /home/${USERNAME}/.bashrc \
 && echo "[ -f /raise_ros2_ws/install/setup.bash ] && source /raise_ros2_ws/install/setup.bash" >> /home/${USERNAME}/.bashrc

# Pre-disable Gazebo Quick Start dialog (avoids Fuel network hang on first run).
RUN mkdir -p /home/${USERNAME}/.gz/sim/8 \
 && echo '<?xml version="1.0"?>' > /home/${USERNAME}/.gz/sim/8/gui.config \
 && echo '<dialog name="quick_start" show_again="false"/>' >> /home/${USERNAME}/.gz/sim/8/gui.config

COPY --chmod=755 docker/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
