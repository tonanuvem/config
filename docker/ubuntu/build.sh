git pull && docker stop webconfig && docker rmi config
docker build --progress=plain -t config .
