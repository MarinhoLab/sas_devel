FROM ghcr.io/marinholab/gazebo:jazzy
LABEL authors="murilomarinho"
SHELL ["/bin/bash", "-c"]
ENV BASH_ENV="/etc/bash_env"

RUN sudo apt-get update && sudo apt-get upgrade -y
RUN sudo apt-get install -y dh-make devscripts

# install sas_cpp as a .deb
# The context ships no .git (Dockerfile.dockerignore), so version.sh takes
# the commit count from this build arg (see compose.yml; default stamps a
# placeholder - only the deb builder publishes real versions).
ARG SAS_CPP_NN=0
ENV SAS_CPP_NN=${SAS_CPP_NN}
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