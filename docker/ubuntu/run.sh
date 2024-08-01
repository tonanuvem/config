docker run --name config -p 4200:4200 -d config
docker run -ti --name config -d config /bin/bash 
docker exec -ti config /bin/bash
