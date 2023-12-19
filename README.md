# enclave-gpu

## Steps

```sh
cd /home/blyss/hopper-enclave/enclave-gpu

# rm /home/blyss/hopper-enclave/enclave-gpu/kernel/images/disk.qcow2

# Create two blank .qcow2 images
qemu-img create -f qcow2 -o preallocation=metadata /home/blyss/hopper-enclave/enclave-gpu/kernel/images/disk.qcow2 100G
qemu-img create -f qcow2 -o preallocation=metadata /home/blyss/hopper-enclave/enclave-gpu/kernel/images/scratch.qcow2 50G

# Mount the Ubuntu ISO
sudo mount -r kernel/iso/ubuntu-22.04.2-live-server-amd64.iso /mnt

# Start a web server containing the user-data
cd kernel/iso && python3 -m http.server 3003 &

# Launch a standard (non-AmdSevX64, OVMF_CODE + OVMF_VARS) VM with Ubuntu ISO
# (nb: important not to set default-network here on first boot, and to give it enough memory)
# (takes 10 minutes)
cd kernel/qemu && sudo ./launch-qemu-AmdSevX64.old.sh \
  -oldfw \
  -mem 8192 \
  -hda ../images/disk.qcow2 \
  -cdrom ../iso/ubuntu-22.04.2-live-server-amd64.iso \
  -kernel /mnt/casper/vmlinuz \
  -initrd /mnt/casper/initrd \
  -append 'console=ttyS0 earlyprintk=serial autoinstall ds=nocloud-net;s=http://_gateway:3003/'

# Launch VM
# (takes 1-3 minutes to boot)
sudo screen -d -m ./launch-qemu-AmdSevX64.old.sh \
  -oldfw \
  -mem 8192 \
  -default-network \
  -hda ../images/disk.qcow2

# Copy .debs for changing kernel to 6.5-rc2
scp -i ../../services/dummy_ssh_key -P 8000 ../images/debs/linux-headers-6.5.0-rc2-snp-guest-ad9c0bf475ec_6.5.0-rc2-gad9c0bf475ec-2_amd64.deb ../images/debs/linux-image-6.5.0-rc2-snp-guest-ad9c0bf475ec_6.5.0-rc2-gad9c0bf475ec-2_amd64.deb guest@localhost:/home/guest/

# Run debs on guest
ssh -i ../../services/dummy_ssh_key -p 8000 guest@localhost 'sudo dpkg -i *.deb'

# Copy modules loader, re-run update-initramfs
scp -i ../../services/dummy_ssh_key -P 8000 ../../services/modules.txt guest@localhost:/home/guest/
ssh -i ../../services/dummy_ssh_key -p 8000 guest@localhost 'sudo mv /home/guest/modules.txt /etc/initramfs-tools/modules'
ssh -i ../../services/dummy_ssh_key -p 8000 guest@localhost 'sudo update-initramfs -u'

# Extract initrd
scp -i ../../services/dummy_ssh_key -P 8000 guest@localhost:/boot/initrd.img-6.5.0-rc2-snp-guest-ad9c0bf475ec /home/blyss/hopper-enclave/enclave-gpu/kernel/images/

# Shutdown the VM
ssh -i ../../services/dummy_ssh_key -p 8000 guest@localhost 'sudo shutdown now'

# Re-launch with new kernel
sudo screen -d -m ./launch-qemu-AmdSevX64.old.sh \
  -mem 8192 \
  -default-network \
  -hda ../images/disk.qcow2 \
  -kernel ../images/vmlinuz-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -initrd ../images/initrd.img-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -append 'console=ttyS0 earlyprintk=serial'

# Copy service and setup scripts
scp -i ../../services/dummy_ssh_key -P 8000 ../../services/setup.sh ../../services/docker-runner.sh ../../services/docker-runner.service  ../../services/blyss-nvidia-persistenced.service ../../services/ncr-config.toml guest@localhost:/home/guest/

# Copy NCR config
ssh -i ../../services/dummy_ssh_key -p 8000 guest@localhost 'sudo cp /home/guest/ncr-config.toml /etc/nvidia-container-runtime/config.toml'

# Run the setup script
ssh -i ../../services/dummy_ssh_key -p 8000 guest@localhost 'chmod +x /home/guest/setup.sh && sudo /home/guest/setup.sh'

# Shutdown the VM
ssh -i ../../services/dummy_ssh_key -p 8000 guest@localhost 'sudo shutdown now'

# blacklist nouveau??
# cat <<EOF | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
# blacklist nouveau
# options nouveau modeset=0
# EOF
#
# scp -i ../../services/dummy_ssh_key -P 8000 guest@localhost:/boot/initrd.img-6.5.0-rc2-snp-guest-ad9c0bf475ec /home/blyss/hopper-enclave/enclave-gpu/kernel/images/

  # -sev-snp \

# 2min:
# sudo docker build -t local/llama.cpp:full-cuda --build-arg CUDA_VERSION=12.2.2 -f .devops/full-cuda.Dockerfile .
# cd models:
# sudo DOCKER_BUILDKIT=1 docker build -t local/server:llamacpp -f Dockerfile .

# Relaunch the VM with GPU
# (takes 1-3 minutes to boot)
sudo screen -d -m ./launch-qemu-AmdSevX64.old.sh \
  -gpu \
  -mem 60000 \
  -default-network \
  -hda ../images/disk.qcow2 \
  -kernel ../images/vmlinuz-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -initrd ../images/initrd.img-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -append "console=ttyS0 earlyprintk=serial root=/dev/sda2"


# alternate docker image for testing:
# httpd@sha256:42ed559bb8529283236b537155e345b47051ed082200c7d7e155405b3e169235
# fsck.mode=skip ro console=ttyS0 overlayroot=tmpfs root=/dev/sda2 rootflags=noload blyss_docker_img=httpd@sha256:42ed559bb8529283236b537155e345b47051ed082200c7d7e155405b3e169235 initrd=initrd
# blintzbase/llm-api@sha256:a24d7b969278062741cb7db6cce7dc4bdd87c17a4f4a65322916af888e1eeebd
# docker storage driver must be fuse-overlayfs to run properly w/ overlayfs...
# DEB_PYTHON_INSTALL_LAYOUT=deb_system pip3 install .

sudo ./launch-qemu-AmdSevX64.old.sh \
  -mem 8192 \
  -default-network \
  -hda ../images/disk-sparse.qcow2 \
  -kernel ../images/vmlinuz-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -initrd ../images/initrd.img-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -append "console=ttyS0 earlyprintk=serial root=/dev/sda2" 

sudo ./launch-qemu-AmdSevX64.old.sh \
  -gpu \
  -sev-snp \
  -mem 8192 \
  -default-network \
  -hda ../images/disk-sparse.qcow2 \
  -hdb ../images/scratch.qcow2 \
  -readonly \
  -kernel ../images/vmlinuz-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -initrd ../images/initrd.img-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -append "rd.modules_load=dm_verity fsck.mode=skip ro console=ttyS0 overlayroot=tmpfs root=/dev/dm-0 rootflags=noload dm-mod.create=\\\"dmverity,,0,ro,0 1046370304 verity 1 /dev/sda2 /dev/sdb 4096 4096 130796288 1 sha256 db0dc6f3dbade397fabab9b07f384c76414df3b9ba97087c0824f4a1d4416895 0000000000000000000000000000000000000000000000000000000000000000 1 ignore_corruption\\\"" 
  

sudo screen -d -m ./launch-qemu-AmdSevX64.old.sh \
  -gpu \
  -sev-snp \
  -mem 8192 \
  -readonly \
  -default-network \
  -hda ../images/disk.qcow2 \
  -kernel ../images/vmlinuz-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -initrd ../images/initrd.img-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -append "fsck.mode=skip ro console=ttyS0 overlayroot=tmpfs root=/dev/sda2 rootflags=noload blyss_docker_img=blintzbase/llm-api@sha256:a24d7b969278062741cb7db6cce7dc4bdd87c17a4f4a65322916af888e1eeebd" 


sudo ./launch-qemu-AmdSevX64.old.sh \
  -gpu \
  -sev-snp \
  -mem 98304 \
  -default-network \
  -hda ../images/disk-sparse.qcow2 \
  -hdb ../images/scratch.qcow2 \
  -kernel ../images/vmlinuz-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -initrd ../images/initrd.img-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -append "fsck.mode=skip ro console=ttyS0 overlayroot=tmpfs root=/dev/sda2 rootflags=noload \
blyss_disable_server blyss_use_test_cert \
blyss_shim_docker_img=\\\"blintzbase/shim@sha256:f3716260a4ee595ff497ef12c183f58378cf85be0208b9c568062f2b092d4fb7\\\" \
blyss_ui_docker_img=\\\"--env DEFAULT_MODEL=mistralai/Mistral-7B-Instruct-v0.1 --env OPENAI_API_HOST=https://enclave.blyss.dev --env NODE_TLS_REJECT_UNAUTHORIZED=0 blintzbase/chatui@sha256:1eed65143ae36d72bfe9ca2633306cd600e4b689d55b4cf17fee86fea22d4f88\\\" \
blyss_docker_img=\\\"--env HUGGING_FACE_HUB_TOKEN=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 vllm/vllm-openai@sha256:d4b96484ebd0d81742f0db734db6b0e68c44e252d092187935216e0b212afc24 --model mistralai/Mistral-7B-Instruct-v0.1 \\\""


# blyss_ui_docker_img=\\\"--env 'CUSTOM_MODELS=-all,+mistralai/Mistral-7B-v0.1' --env 'BASE_URL=https://app:8000' yidadaa/chatgpt-next-web@sha256:ca127036661c80c0e567a4a8afdd00666e8e56c000f4a1ac90c1098f7c892ebd\\\"

# sudo docker run --runtime nvidia --gpus all \
#     -p 8080:8000 \
#     --env "HUGGING_FACE_HUB_TOKEN=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" \
#     vllm/vllm-openai:latest \
#     --model mistralai/Mistral-7B-v0.1 \
#     --revision 5e9c98b96d071dce59368012254c55b0ec6f8658

# sudo journalctl -n 100 -f -u docker-runner

# on host reboot, do:
# sudo modprobe vfio-pci
# sudo sh -c "echo 10de 2331 > /sys/bus/pci/drivers/vfio-pci/new_id"

# Launch again, this time with readonly disk and overlay
sudo ./launch-qemu-AmdSevX64.old.sh \
  -gpu \
  -sev-snp \
  -kernel ../images/vmlinuz-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -initrd ../images/initrd.img-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -mem 8192 \
  -readonly \
  -hda ../images/disk-sparse.qcow2 \
  -hdb ../images/scratch.qcow2 \
  -default-network \
  -append "fsck.mode=skip ro console=ttyS0 overlayroot=tmpfs root=/dev/sda2 rootflags=noload" 

# Run veritysetup to compute hash
ssh -i ../../services/dummy_ssh_key -p 8000 guest@localhost 'time sudo veritysetup --debug --format=1 --data-block-size=4096 --hash-block-size=4096 --data-blocks=130796240 --hash-offset=0 --salt=0000000000000000000000000000000000000000000000000000000000000000 format /dev/sda2 /dev/sdb'

# Launch with verity check
sudo screen -L -Logfile ~/hopper-enclave/log-1.txt -d -m ./launch-qemu-AmdSevX64.old.sh \
  -gpu \
  -sev-snp \
  -mem 114688 \
  -smp 8 \
  -default-network \
  -hda ../images/disk-sparse.qcow2 \
  -hdb ../images/scratch.qcow2 \
  -readonly \
  -kernel ../images/vmlinuz-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -initrd ../images/initrd.img-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -append "blyss_disable_server blyss_use_test_cert \
fsck.mode=skip ro console=ttyS0 overlayroot=tmpfs root=/dev/dm-0 rootflags=noload dm-mod.create=\\\"dmverity,,0,ro,0 1046369920 verity 1 /dev/sda2 /dev/sdb 4096 4096 130796240 1 sha256 c51b4b94ee613a768cf555442582b9bcf6e8b04aacd26ff52cd69f87809b8190 0000000000000000000000000000000000000000000000000000000000000000 1 panic_on_corruption\\\" \
blyss_shim_docker_img=\\\"blintzbase/shim@sha256:6652a8cc8a752eb9bc2d076daa6c346ca156c7b5bfbcf7c5021c9fd7bbc238bf\\\" \
blyss_ui_docker_img=\\\"--env DEFAULT_MODEL=mistralai/Mixtral-8x7B-Instruct-v0.1 --env OPENAI_API_HOST=https://enclave.blyss.dev --env NODE_TLS_REJECT_UNAUTHORIZED=0 blintzbase/chatui@sha256:fc2e543e8d020a71f8dc2a4737f5d9073f688b6e8f514fa3061b2002db46d331\\\" \
blyss_docker_img=\\\"--env HUGGING_FACE_HUB_TOKEN=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 ghcr.io/mistralai/mistral-src/vllm@sha256:901c65ada9ceabaebc40964418fdc0ccef406518035f7cd7316b09283ceaf29e --host 0.0.0.0 --model mistralai/Mixtral-8x7B-Instruct-v0.1 --load-format pt\\\""



sev-snp-measure --vcpus 4 --vcpu-type EPYC-v4 --ovmf ~/hopper-enclave/enclave-gpu/kernel/qemu/qemu_new/usr/local/share/qemu/OVMF.fd --kernel ../../enclave-gpu/kernel/images/vmlinuz-6.5.0-rc2-snp-guest-ad9c0bf475ec --initrd ../../enclave-gpu/kernel/images/initrd.img-6.5.0-rc2-snp-guest-ad9c0bf475ec --mode snp --append "blyss_disable_server blyss_use_test_cert fsck.mode=skip ro console=ttyS0 overlayroot=tmpfs root=/dev/dm-0 rootflags=noload dm-mod.create=\"dmverity,,0,ro,0 1046369920 verity 1 /dev/sda2 /dev/sdb 4096 4096 130796240 1 sha256 c51b4b94ee613a768cf555442582b9bcf6e8b04aacd26ff52cd69f87809b8190 0000000000000000000000000000000000000000000000000000000000000000 1 panic_on_corruption\" blyss_shim_docker_img=\"blintzbase/shim@sha256:6652a8cc8a752eb9bc2d076daa6c346ca156c7b5bfbcf7c5021c9fd7bbc238bf\" blyss_ui_docker_img=\"--env DEFAULT_MODEL=mistralai/Mistral-7B-Instruct-v0.1 --env OPENAI_API_HOST=https://enclave.blyss.dev --env NODE_TLS_REJECT_UNAUTHORIZED=0 blintzbase/chatui@sha256:404c2bfefca0b086c064c16fcb33a3262ca9a87e0b0d541b3fb48d62c772a3d8\" blyss_docker_img=\"--env HUGGING_FACE_HUB_TOKEN=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 vllm/vllm-openai@sha256:d4b96484ebd0d81742f0db734db6b0e68c44e252d092187935216e0b212afc24 --model mistralai/Mistral-7B-Instruct-v0.1 \""
```