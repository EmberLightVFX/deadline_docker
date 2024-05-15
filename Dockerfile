FROM ubuntu:20.04

WORKDIR /build

RUN apt-get update && apt-get install -y curl file bzip2 unzip

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" &&\
    unzip awscliv2.zip &&\
    ./aws/install  &&\
    rm awscliv2.zip &&\
    rm -rf ./aws

RUN mkdir ~/certs &&\
    mkdir /installers &&\
    mkdir /unpacked_installers

#Install Database
RUN mkdir -p /opt/Thinkbox/DeadlineDatabase10/mongo/data &&\
    mkdir -p /opt/Thinkbox/DeadlineDatabase10/mongo/application &&\
    mkdir -p /opt/Thinkbox/DeadlineDatabase10/mongo/application/bin &&\
    mkdir -p /opt/data

# Add MongoDB bin directory to PATH
ENV PATH="/opt/Thinkbox/DeadlineDatabase10/mongo/application/bin:${PATH}"

COPY ./database_config/config.conf /opt/data/config.conf

ADD ./entrypoint.sh .
RUN chmod u+x ./entrypoint.sh

ENTRYPOINT [ "./entrypoint.sh" ]
