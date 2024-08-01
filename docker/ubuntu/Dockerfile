FROM ubuntu:24.10

WORKDIR /home/ubuntu/environment
RUN git clone https://github.com/tonanuvem/config/
RUN touch /home/ubuntu/environment/labsuser.pem

WORKDIR /home/ubuntu/environment
RUN sh /home/ubuntu/environment/preparar.sh

VOLUME /home/ubuntu/environment/.aws
VOLUME /home/ubuntu/environment/.kube
