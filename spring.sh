#!/bin/bash

echo "\n\nInstalação do SPRING:\n\n"

cd ~/environment
curl -s "https://get.sdkman.io" | bash > /dev/null
bash ~/.sdkman/bin/sdkman-init.sh
. "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install springboot 2.7.10
spring version
