#!/bin/bash

sudo mkdir -p /opt/google/cuda-installer || true
cd /opt/google/cuda-installer/

sudo curl -fSsL -O https://storage.googleapis.com/compute-gpu-installation-us/installer/latest/cuda_installer.pyz
sudo python3 cuda_installer.pyz install_cuda
#sudo reboot -f