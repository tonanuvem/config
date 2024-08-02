#docker run --hostname fiap --name webconfig --rm -p 4200:4200 -d config /bin/bash
docker stop webconfig && git pull
docker run --rm -ti --name webconfig -d config /bin/bash 
docker exec -ti webconfig /bin/bash
