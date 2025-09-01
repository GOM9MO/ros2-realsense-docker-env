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
RUN apt-get update \
    && export ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F "tag_name" | awk -F\" '{print $4}') \
    && curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo $VERSION_CODENAME)_all.deb" \
    && dpkg -i /tmp/ros2-apt-source.deb \
    && rm /tmp/ros2-apt-source.deb

# 安装开发工具（可选）
RUN #apt-get update && apt-get install -y ros-dev-tools

# 更新系统并安装 ROS 2 Desktop 版本
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
RUN echo "source /opt/ros/jazzy/setup.bash" >> /home/$USERNAME/.bashrc
ENV ROS_DISTRO=jazzy

# 更改工作目录所有权
RUN chown -R $USERNAME:$USERNAME /home/$USERNAME

# 切换到非root用户
USER $USERNAME

# 设置默认shell
SHELL ["/bin/bash", "-c"]

# 默认启动bash
CMD ["/bin/bash"]
