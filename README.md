# gpu-enclave-img

This repository contains code for the base disk image
of the Blyss Confidential AI service, at [enclave.blyss.dev](https://enclave.blyss.dev).
For more details, see [this technical deep-dive](https://blog.blyss.dev/confidential-ai-from-gpu-enclaves/).

## Setup

This is a full outline of the steps we used to build the base disk image. We assume that the repo has been cloned to `~/gpu-enclave-img`.

```sh
# Create two blank .qcow2 images
qemu-img create -f qcow2 -o preallocation=metadata ~/gpu-enclave-img/kernel/images/disk.qcow2 100G
qemu-img create -f qcow2 -o preallocation=metadata ~/gpu-enclave-img/kernel/images/scratch.qcow2 50G

# Mount the base Ubuntu ISO
sudo mount -r kernel/iso/ubuntu-22.04.2-live-server-amd64.iso /mnt

# Start a web server containing the user-data
cd kernel/iso && python3 -m http.server 3003 &

# Launch a standard (non-AmdSevX64, OVMF_CODE + OVMF_VARS) VM with Ubuntu ISO
# (nb: important not to set default-network here on first boot, and to give it enough memory)
# (this step takes roughly 10 minutes)
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

# Copy .debs for changing kernel to '6.5.0-rc2-snp-guest-ad9c0bf475ec'
scp -i ../../services/dummy_ssh_key -P 8000 ../images/debs/linux-headers-6.5.0-rc2-snp-guest-ad9c0bf475ec_6.5.0-rc2-gad9c0bf475ec-2_amd64.deb ../images/debs/linux-image-6.5.0-rc2-snp-guest-ad9c0bf475ec_6.5.0-rc2-gad9c0bf475ec-2_amd64.deb guest@localhost:/home/guest/

# Run .debs on guest
ssh -i ../../services/dummy_ssh_key -p 8000 guest@localhost 'sudo dpkg -i *.deb'

# Copy the modules loader and re-run update-initramfs
scp -i ../../services/dummy_ssh_key -P 8000 ../../services/modules.txt guest@localhost:/home/guest/
ssh -i ../../services/dummy_ssh_key -p 8000 guest@localhost 'sudo mv /home/guest/modules.txt /etc/initramfs-tools/modules'
ssh -i ../../services/dummy_ssh_key -p 8000 guest@localhost 'sudo update-initramfs -u'

# Extract the initrd
scp -i ../../services/dummy_ssh_key -P 8000 guest@localhost:/boot/initrd.img-6.5.0-rc2-snp-guest-ad9c0bf475ec ~/gpu-enclave-img/kernel/images/

# Shut down the VM
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

# Copy NVIDIA Container Runtime configuration
ssh -i ../../services/dummy_ssh_key -p 8000 guest@localhost 'sudo cp /home/guest/ncr-config.toml /etc/nvidia-container-runtime/config.toml'

# Run the setup script
ssh -i ../../services/dummy_ssh_key -p 8000 guest@localhost 'chmod +x /home/guest/setup.sh && sudo /home/guest/setup.sh'

# Shutdown the VM
ssh -i ../../services/dummy_ssh_key -p 8000 guest@localhost 'sudo shutdown now'
```

## `dm-verity`
Our [security model](https://blog.blyss.dev/confidential-ai-from-gpu-enclaves/#from-trusted-boot-to-a-trusted-application) 
relies on the `dm-verity` kernel module to hash and verify the contents of the
secure VM's disk. To compute the `dm-verity` hash and associated metadata (stored in
`hdb`) of the disk, follow these steps:

```sh
# Launch again, this time with readonly disk and overlay
sudo ./launch-qemu-AmdSevX64.old.sh \
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
```

## Building

We are still working towards being able to build this disk image in CI.
Until then, we publish the [~20 GB disk image](https://spiraldb.xyz/data/disk-sparse.qcow2) that we use.