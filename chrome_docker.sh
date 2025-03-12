# https://github.com/tonanuvem/chrome

# https://github.com/bonigarcia/novnc
# https://github.com/siomiz/chrome

docker network create chrome
docker run --rm --name chrome -p 5900:5900 --net chrome -d siomiz/chrome
docker run --rm --name novnc -p 6080:6080 --net chrome -e AUTOCONNECT=true -e VNC_SERVER=chrome:5900 -d bonigarcia/novnc:1.2.0

echo ""
ip=$(curl -s checkip.amazonaws.com)
echo ""
echo "Acessar: http://$ip:6080"
#echo "Acessar: https://$ip:8843"
echo ""
echo ""
