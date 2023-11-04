#!/bin/bash

# 1. Install Docker
apt-get update && apt-get install -y apt-transport-https ca-certificates curl software-properties-common && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable" && apt-cache policy docker-ce && apt-get install -y docker-ce && systemctl status docker

# 2. Install the NVIDIA drivers
# apt-get install -y gcc g++ make
# wget https://developer.download.nvidia.com/compute/cuda/12.2.1/local_installers/cuda_12.2.1_535.86.10_linux.run
# sh cuda_12.2.1_535.86.10_linux.run -m=kernel-open --silent
# export PATH=/usr/local/cuda-12.2/bin${PATH:+:${PATH}}
# export LD_LIBRARY_PATH=/usr/local/cuda-12.2/lib64\
#                          ${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}

cp /home/guest/blyss-nvidia-persistenced.service /etc/systemd/system/blyss-nvidia-persistenced.service
systemctl enable blyss-nvidia-persistenced.service

# 2. Install NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list \
  && \
    apt-get update

apt-get install -y nvidia-container-toolkit

# 3. Set up NVIDIA runtime
nvidia-ctk runtime configure --runtime=docker

# 4. Restart Docker
systemctl restart docker

# 5. Enable docker-runner service
cp /home/guest/docker-runner.service /etc/systemd/system/docker-runner.service
systemctl enable docker-runner.service

