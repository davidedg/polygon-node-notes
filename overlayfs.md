# Overlayfs to combine multiple disks

Let's say you want to pre-download the snapshots with multiple disks with differente Internet connections, e.g.:

- Disk 1, mounted on /mnt/net-disk-to-inet-1
- Disk 2, mounted on /mnt/net-disk-to-inet-2

Then you can combine them with overlayfs into a single /mnt/data/bor-tmp:

    mount -v -t overlay overlay -o lowerdir=/mnt/net-disk-to-inet-1/bor-tmp,upperdir=/mnt/net-disk-to-inet-2/bor-tmp,workdir=/mnt/net-disk-to-inet-2/bor-tmp-work  /mnt/data/bor-tmp


https://wiki.archlinux.org/title/Overlay_filesystem
