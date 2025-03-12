# https://github.com/tonanuvem/chrome

# https://github.com/bonigarcia/novnc
# https://github.com/siomiz/chrome

docker network create netchrome
docker run --rm --name chrome -p 5900:5900 --net netchrome -e VNC_SCREEN_SIZE=1024x768 -d siomiz/chrome
docker run --rm --name novnc -p 6080:6080 --net netchrome -e AUTOCONNECT=true -e VNC_SERVER=chrome:5900 -d bonigarcia/novnc:1.2.0

echo ""
echo "Chrome executado. Para colar no Navegador, usar o botão da Área de Transferência do menu esquerdo do noVNC"
echo ""
ip=$(curl -s checkip.amazonaws.com)
echo ""
echo "Acessar: http://$ip:6080"
#echo "Acessar: https://$ip:8843"
echo ""
echo ""
