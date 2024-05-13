FROM ubuntu:18.04 as base

WORKDIR /build

RUN apt-get update && apt-get install -y curl dos2unix python python-openssl python-pip git lsb

RUN mkdir ~/keys &&\
    mkdir ~/certs

#Install Certificate Generator
RUN git clone https://github.com/Cherie-Chen/SSLGeneration.git &&\
    pip install pyopenssl awscli
RUN mkdir /client_certs

#Install Database
RUN mkdir -p /opt/Thinkbox/DeadlineDatabase10/mongo/data &&\
    mkdir -p /opt/Thinkbox/DeadlineDatabase10/mongo/application &&\
    mkdir -p /opt/Thinkbox/DeadlineDatabase10/mongo/data/logs
COPY ./database_config/config.conf /opt/Thinkbox/DeadlineDatabase10/mongo/data/

ADD ./entrypoint.sh ./entrypoint/entrypoint.sh
RUN dos2unix ./entrypoint/entrypoint.sh && chmod u+x ./entrypoint/entrypoint.sh

ENTRYPOINT [ "./entrypoint/entrypoint.sh" ]
