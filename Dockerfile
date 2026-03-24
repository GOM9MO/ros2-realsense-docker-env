FROM ubuntu:24.04

# 避免交互式配置
ENV DEBIAN_FRONTEND=noninteractive

# 设置用户名（可以根据需要修改）
ARG USERNAME=ros
ARG USER_UID=1001
ARG USER_GID=$USER_UID

# 创建非root用户
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# 设置工作目录
WORKDIR /home/$USERNAME

# 设置 locale
RUN apt-get update && apt-get install -y locales \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG=en_US.UTF-8

# 启用 required repositories
RUN apt-get update && apt-get install -y \
    software-properties-common \
    curl \
    && add-apt-repository universe

# 添加 ROS 2 apt 源
RUN apt-get update && apt-get install -y curl \
    && export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F'"' '{print $4}') \
    && curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb" \
    && dpkg -i /tmp/ros2-apt-source.deb \
    && rm /tmp/ros2-apt-source.deb

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y \
        ros-jazzy-ros-base \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 安装 rosdep 并初始化
RUN apt-get update \
    && apt-get install -y python3-rosdep \
    && rosdep init \
    && rosdep update

# 设置环境变量
ENV ROS_DISTRO=jazzy
RUN echo "source /opt/ros/$ROS_DISTRO/setup.bash" >> /home/$USERNAME/.bashrc

RUN apt-get update \
    && apt install -y ros-$ROS_DISTRO-cartographer \
    libssl-dev \
    libusb-1.0-0-dev \
    libudev-dev \
    pkg-config \
    libgtk-3-dev \
    git \
    wget \
    cmake \
    build-essential \
    libglfw3-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    v4l-utils \
    udev \
    usbutils \
    python3.12-full \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/IntelRealSense/librealsense.git /opt/librealsense \
    && cd /opt/librealsense \
    && git checkout v2.57.6 \
    && mkdir -p build && cd build \
    && cmake ../ \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_EXAMPLES=false \
        -DBUILD_GRAPHICAL_EXAMPLES=false \
        -DFORCE_RSUSB_BACKEND=true \
        -DBUILD_PYTHON_BINDINGS:bool=true \
        -DPYTHON_EXECUTABLE=/usr/bin/python3.12 \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    && find . -maxdepth 2 -name "pyrealsense2*.so" -exec cp {} /opt/pyrealsense2.so \; \
    && ls -la /opt/pyrealsense2.so \
    && rm -rf /opt/librealsense

RUN python3.12 -m venv /venv \
    && cp /opt/pyrealsense2.so /venv/lib/python3.12/site-packages/pyrealsense2.so

ENV PATH="/venv/bin:$PATH"
ENV LD_LIBRARY_PATH=/usr/local/lib


# env begin

# env end



RUN chown -R $USERNAME:$USERNAME /home/$USERNAME

SHELL ["/bin/bash", "-c"]

CMD ["/bin/bash"]