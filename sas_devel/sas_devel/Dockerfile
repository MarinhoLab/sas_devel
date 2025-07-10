FROM murilomarinho/sas:jazzy
LABEL authors="murilomarinho"
SHELL ["/bin/bash", "-c"]
ENV BASH_ENV="/etc/bash_env"

# Install qtcreator
RUN sudo apt-get update
RUN sudo apt-get install qtcreator -y
# Add setup environment but no need to run it now
COPY scripts/setup_environment.sh /root/setup_environment.sh
RUN cd root \
&& ls \
&& chmod +x setup_environment.sh 
