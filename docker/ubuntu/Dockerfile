FROM ubuntu:24.10

## Pre-reqs : https://github.com/docker-library/postgres/blob/69bc540ecfffecce72d49fa7e4a46680350037f9/9.6/Dockerfile#L21-L24
RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends ca-certificates wget git openssl shellinabox && rm -rf /var/lib/apt/lists/*

RUN mkdir /home/ubuntu/environment
WORKDIR /home/ubuntu/environment
RUN git clone https://github.com/tonanuvem/config/
RUN touch /home/ubuntu/environment/labsuser.pem

WORKDIR /home/ubuntu/environment
RUN sh /home/ubuntu/environment/config/preparar.sh

VOLUME /home/ubuntu/environment/.aws
VOLUME /home/ubuntu/environment/.kube

EXPORT 4200
