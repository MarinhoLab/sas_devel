FROM murilomarinho/sas:jazzy
LABEL authors="murilomarinho"
SHELL ["/bin/bash", "-c"]
ENV BASH_ENV="/etc/bash_env"

RUN mkdir -p 
&& cd ~ 
&& git clone https://github.com/MarinhoLab/sas_devel
&& cd sas_devel/scripts
&& chmod +x setup_enviroment.sh
&& ./setup_enviroment.sh