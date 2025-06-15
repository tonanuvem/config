# Calico
# https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.1/manifests/tigera-operator.yaml

# Cilium
# CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
# CLI_ARCH=amd64
# if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
# curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
# sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
# sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
# rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

# cilium install --version 1.17.4

# cilium status --wait

# cilium connectivity test
