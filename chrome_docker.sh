# https://github.com/tonanuvem/chrome

docker run --rm -d \
  --name=google-chrome \
  --security-opt seccomp=unconfined `#optional` \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -e CHROME_CLI=https://www.fiap.com.br/ `#optional` \
  -p 8888:3000 \
  -p 8843:3001 \
  -v /home/ubuntu/environment/:/config \
  --shm-size="1gb" \
  ghcr.io/tibor309/chrome:latest

echo ""
ip=$(curl -s checkip.amazonaws.com)
echo ""
echo "Acessar: http://$ip:8888"
#echo "Acessar: https://$ip:8843"
echo ""
echo ""
