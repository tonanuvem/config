#!/bin/bash

curl -s "https://get.sdkman.io" | bash > /dev/null
bash ~/.sdkman/bin/sdkman-init.sh
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk install springboot 2.7.10
spring version
