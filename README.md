# enclave-gpu

## Steps

```sh
cd /home/blyss/hopper-enclave/enclave-gpu

# rm /home/blyss/hopper-enclave/enclave-gpu/kernel/images/disk.qcow2

# create a qcow2 image
qemu-img create -f qcow2 -o preallocation=metadata /home/blyss/hopper-enclave/enclave-gpu/kernel/images/disk.qcow2 100G

# mount the iso
sudo mount -r kernel/iso/ubuntu-22.04.2-live-server-amd64.iso /mnt
``
# start web server
cd kernel/iso 
python3 -m http.server 3003 &
cd ../..

# launch standard (non-AmdSevX64, OVMF_CODE + OVMF_VARS) VM with Ubuntu ISO
# important not to set default-network here on first boot, and to give it enough memory
cd kernel/qemu && sudo ./launch-qemu-AmdSevX64.old.sh \
  -oldfw \
  -mem 8192 \
  -hda ../images/disk.qcow2 \
  -cdrom ../iso/ubuntu-22.04.2-live-server-amd64.iso \
  -kernel /mnt/casper/vmlinuz \
  -initrd /mnt/casper/initrd \
  -append 'console=ttyS0 earlyprintk=serial autoinstall ds=nocloud-net;s=http://_gateway:3003/'


# launch VM
sudo ./launch-qemu-AmdSevX64.old.sh \
  -oldfw \
  -mem 8192 \
  -default-network \
  -hda ../images/disk.qcow2

# change kernel to 6.5-rc2
scp -P 8000 ../images/debs/*.deb guest@localhost:/home/guest/

# on guest:
sudo dpkg -i *.deb

# on host:
scp -P 8000 guest@localhost:/boot/initrd.img-6.5.0-rc2-snp-guest-ad9c0bf475ec /home/blyss/hopper-enclave/enclave-gpu/kernel/images/

sudo ./launch-qemu-AmdSevX64.old.sh \
  -mem 8192 \
  -default-network \
  -hda ../images/disk.qcow2 \
  -kernel ../images/vmlinuz-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -initrd ../images/initrd.img-6.5.0-rc2-snp-guest-ad9c0bf475ec \
  -append 'console=ttyS0 earlyprintk=serial'



  # -kernel /mnt/casper/vmlinuz \
  # -initrd /mnt/casper/initrd \
  # -append 'console=ttyS0 earlyprintk=serial root=/dev/sda3'
```