## Bor alternative ancient data

Chain data to ssd drive, ancient data to hdd

    mkdir -p /mnt/datassd/
    mount /dev/vg-data/datassd /mnt/datassd/
    mkdir -p /mnt/datassd/bor/chaindata

    find  /mnt/data/bor -maxdepth 1 -type f  -exec mv -t /mnt/datassd/bor/chaindata {} \+

    ln -s  /mnt/datassd/bor/chaindata   /var/lib/bor/data/bor/chaindata


\
Changes to `/var/lib/bor/config.toml`

  - Change the ancient path to a different drive, even [HDD+SSD-cache](https://github.com/davidedg/linux-notes/blob/main/lvm-cache-raid0.sh)

        sed -i 's|^ancient\s*=.*|ancient = "/mnt/data/bor/ancient"|g' /var/lib/bor/config.toml
