FROM ghcr.io/marinholab/gazebo:jazzy
LABEL authors="murilomarinho"
SHELL ["/bin/bash", "-c"]
ENV BASH_ENV="/etc/bash_env"

RUN sudo apt-get update && sudo apt-get upgrade -y
RUN sudo apt-get install -y dh-make devscripts

# install sas_cpp as a .deb
RUN mkdir -p /root/sas_devel/ros2_ws
COPY sas_cpp /root/sas_devel/sas_cpp
WORKDIR /root/sas_devel/sas_cpp
RUN bash tools/bump-changelog.sh
RUN dpkg-buildpackage -us -uc -b
RUN cd .. && dpkg -i ./libmarinholab-sas-core_*.deb

# install sas_py with pip
RUN mkdir -p /root/sas_devel/sas_py
COPY sas_py /root/sas_devel/sas_py
WORKDIR /root/sas_devel/sas_py
RUN pip install . --break-system-packages

# Copy the ROS2 packages
RUN mkdir -p /root/sas_devel/ros2_ws/src/
COPY ./src /root/sas_devel/ros2_ws/src