#!/bin/bash


cd /opt/google/cuda-installer/
sudo python3 cuda_installer.pyz install_cuda --installation-mode=binary

## install nvidia drivers and toolkit
#wget https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb
#dpkg -i cuda-keyring_1.1-1_all.deb
#rm cuda-keyring_1.1-1_all.deb
#sudo apt update
#sudo apt install -y cuda-drivers
#sudo apt install -y cuda-toolkit-12-8

cd /tmp
# install nvidia GPU drivers and toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update

export NVIDIA_CONTAINER_TOOLKIT_VERSION=1.17.8-1
sudo apt-get install -y \
  nvidia-container-toolkit=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
  nvidia-container-toolkit-base=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
  libnvidia-container-tools=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
  libnvidia-container1=${NVIDIA_CONTAINER_TOOLKIT_VERSION}

sudo nvidia-ctk runtime configure --runtime=docker

# nomad nvidia plugin
sudo mkdir -p /opt/nomad/plugins
curl -fsSL https://releases.hashicorp.com/nomad-device-nvidia/1.1.0/nomad-device-nvidia_1.1.0_linux_amd64.zip -o nomad-device-nvidia.zip
unzip -j nomad-device-nvidia.zip nomad-device-nvidia
sudo mv nomad-device-nvidia /opt/nomad/plugins
rm nomad-device-nvidia.zip

sudo nvidia-smi
