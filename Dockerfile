FROM ubuntu:20.04

WORKDIR /build

RUN mkdir ~/keys &&\
    mkdir ~/certs &&\
    mkdir /installers &&\
    mkdir /unpacked_installers

#Install Database
RUN mkdir -p /opt/Thinkbox/DeadlineDatabase10/mongo/data &&\
    mkdir -p /opt/Thinkbox/DeadlineDatabase10/mongo/data/logs &&\
    mkdir -p /opt/Thinkbox/DeadlineDatabase10/mongo/application &&\
    mkdir -p /opt/data

COPY ./database_config/config.conf /opt/data/config.conf

ADD ./entrypoint.sh .
RUN chmod u+x ./entrypoint.sh

ENTRYPOINT [ "./entrypoint.sh" ]
