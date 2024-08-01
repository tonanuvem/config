FROM ubuntu:24.10

## Pre-reqs : https://github.com/docker-library/postgres/blob/69bc540ecfffecce72d49fa7e4a46680350037f9/9.6/Dockerfile#L21-L24
RUN set -x \
	&& apt-get update && apt-get install -y --no-install-recommends ca-certificates wget git && rm -rf /var/lib/apt/lists/*

## Pre-reqs : https://github.com/sspreitzer/shellinabox-container-image/blob/main/ubuntu/Dockerfile
RUN apt-get update && apt-get install -y openssl curl openssh-client sudo shellinabox && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    ln -sf '/etc/shellinabox/options-enabled/00+Black on White.css' \
      /etc/shellinabox/options-enabled/00+Black-on-White.css && \
    ln -sf '/etc/shellinabox/options-enabled/00_White On Black.css' \
      /etc/shellinabox/options-enabled/00_White-On-Black.css && \
    ln -sf '/etc/shellinabox/options-enabled/01+Color Terminal.css' \
      /etc/shellinabox/options-enabled/01+Color-Terminal.css

USER ubuntu

RUN mkdir /home/ubuntu/environment
WORKDIR /home/ubuntu/environment
RUN git clone https://github.com/tonanuvem/config/
RUN touch /home/ubuntu/environment/labsuser.pem

WORKDIR /home/ubuntu/environment
#RUN sh /home/ubuntu/environment/config/preparar.sh
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python3.12 pip python3.12-venv 
#RUN python3 -m venv pip
RUN pip install --upgrade pip --break-system-packages && sudo python3 -m pip install ansible --break-system-packages


VOLUME /home/ubuntu/environment/.aws
VOLUME /home/ubuntu/environment/.kube
VOLUME /etc/shellinabox /var/log/supervisor

EXPOSE 4200

ADD shellinabox/entrypoint.sh /usr/local/sbin/

ENTRYPOINT ["entrypoint.sh"]
CMD ["shellinabox"]
