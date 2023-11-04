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
scp -i ../../services/dummy_ssh_key -P 8000 ../../services/setup.sh ../../services/docker-runner.sh ../../services/docker-runner.service  ../../services/blyss-nvidia-persistenced.service guest@localhost:/home/guest/

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


# Launch again, this time with readonly disk and overlay
sudo ./launch-qemu-AmdSevX64.sh \
  -kernel ../images/vmlinuz-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -initrd ../images/initrd.img-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -mem 8192 \
  -readonly \
  -hda ../images/disk.qcow2 \
  -hdb ../images/scratch.qcow2 \
  -default-network \
  -append "fsck.mode=skip ro console=ttyS0 overlayroot=tmpfs root=/dev/sda2 rootflags=noload" 

# Run veritysetup to compute hash
ssh -i ../../services/dummy_ssh_key -P 8000 guest@localhost 'time sudo veritysetup --verbose --format=1 --data-block-size=4096 --hash-block-size=4096 --data-blocks=130796288 --hash-offset=0 --salt=0000000000000000000000000000000000000000000000000000000000000000 format /dev/sda2 /dev/sdb'
```