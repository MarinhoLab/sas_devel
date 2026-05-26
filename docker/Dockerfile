FROM ghcr.io/marinholab/gazebo:jazzy
LABEL authors="murilomarinho"
SHELL ["/bin/bash", "-c"]
ENV BASH_ENV="/etc/bash_env"

RUN sudo apt-get update && sudo apt-get upgrade -y
RUN mkdir -p /root/sas_devel/src/