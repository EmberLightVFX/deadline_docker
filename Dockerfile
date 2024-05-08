FROM ubuntu:18.04 as base

WORKDIR /build

RUN apt-get update && apt-get install -y curl dos2unix python python-pip git



FROM base as db

RUN mkdir ~/keys

#Install Certificate Generator
RUN git clone https://github.com/ThinkboxSoftware/SSLGeneration.git &&\
    pip install pyopenssl==17.5.0

RUN mkdir /client_certs

#Install Database
RUN mkdir -p /opt/Thinkbox/DeadlineDatabase10/mongo/data &&\
    mkdir -p /opt/Thinkbox/DeadlineDatabase10/mongo/application &&\
    mkdir -p /opt/Thinkbox/DeadlineDatabase10/mongo/data/logs

COPY ./database_config/config.conf /opt/Thinkbox/DeadlineDatabase10/mongo/data/

RUN curl https://downloads.mongodb.org/linux/mongodb-linux-x86_64-ubuntu1804-4.2.12.tgz -o mongodb-linux-x86_64-ubuntu1804-4.2.12.tgz 
RUN tar -xvf mongodb-linux-x86_64-ubuntu1804-4.2.12.tgz
RUN mv mongodb-linux-x86_64-ubuntu1804-4.2.12/bin /opt/Thinkbox/DeadlineDatabase10/mongo/application/
RUN rm mongodb-linux-x86_64-ubuntu1804-4.2.12.tgz && rm -rf mongodb-linux-x86_64-ubuntu1804-4.2.12

ADD ./database_entrypoint.sh .
RUN dos2unix ./database_entrypoint.sh && chmod u+x ./database_entrypoint.sh

ENTRYPOINT [ "./database_entrypoint.sh" ]



FROM base as client

RUN mkdir ~/certs

RUN pip install awscli
RUN apt-get install -y lsb


ADD ./client_entrypoint.sh .
RUN dos2unix ./client_entrypoint.sh && chmod u+x ./client_entrypoint.sh

ENTRYPOINT [ "./client_entrypoint.sh" ]
