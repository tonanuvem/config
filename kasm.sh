# https://kasmweb.com/downloads
# https://kasmweb.com/docs/latest/install/system_requirements.html#operating-system
# https://kasmweb.com/docs/latest/install/single_server_install.html

cd /tmp
curl -O https://kasm-static-content.s3.amazonaws.com/kasm_release_1.15.0.06fdc8.tar.gz
tar -xf kasm_release_1.15.0.06fdc8.tar.gz
sudo bash kasm_release/install.sh --accept-eula --swap-size 8192 --admin-password fiap --user-password fiap --slim-images
