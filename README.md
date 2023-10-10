# polygon-node-notes
Notes on building a Polygon node on a Debian node


Download the snapshot downloader script:

    wget https://github.com/davidedg/polygon-node-notes/raw/main/snapdown.sh

## Heimdall (req ports: 26656 tcp)

Get and install the latest stable release from https://github.com/maticnetwork/heimdall/releases

    wget https://github.com/maticnetwork/heimdall/releases/download/v1.0.2/heimdalld-v1.0.2-amd64.deb
    wget https://github.com/maticnetwork/heimdall/releases/download/v1.0.2/heimdalld-mainnet-validator-config_v1.0.2-amd64.deb
    apt install ./heimdalld-v1.0.2-amd64.deb ./heimdalld-mainnet-validator-config_v1.0.2-amd64.deb
        
Download Heimdall snapshots (this might take hours)

    tmux
    bash snapdown.sh -n mainnet -c heimdall -d /mnt/data/heimdall -t /mnt/data/heimdall-tmp -v true -z true -k false

Dont run Heimdall on boot (optional)

    systemctl disable heimdalld

Edit the unit definition if required (e.g.: change User to root or change the "--chain=mainnet" - but for this you'd be better off with starting with a different profile deb)

        systemctl edit heimdalld.service
        systemctl daemon-reload

Use a pre-populated address book file ( [example](./addrbook.json) ), put it under `/var/lib/heimdall/config/`

Changes to `/var/lib/heimdall/config/config.toml`

        laddr = "tcp://127.0.0.1:26657"

  - change to 0.0.0.0 if needed - this port does not need be published to the Internet.

  - configure list of initial nodes (seeds) - get them from https://wiki.polygon.technology/docs/pos/operate/node/full-node-binaries/#configure-heimdall-seeds-mumbai

        sed -i 's|^seeds\s*=.*|seeds = "1500161dd491b67fb1ac81868952be49e2509c9f@52.78.36.216:26656,dd4a3f1750af5765266231b9d8ac764599921736@3.36.224.80:26656,8ea4f592ad6cc38d7532aff418d1fb97052463af@34.240.245.39:26656,e772e1fb8c3492a9570a377a5eafdb1dc53cd778@54.194.245.5:26656,6726b826df45ac8e9afb4bdb2469c7771bd797f1@52.209.21.164:26656"|g' /var/lib/heimdall/config/config.toml

  - set the public ip address (if under NAT)

        external_address = "1.2.3.4"

\

Symlink the downloaded snaphot to data directory

    sudo -u heimdall  ln -s /mnt/data/heimdall /var/lib/heimdall/data 

Reset permissions to heimdall user (mind the `-L` switch !)

    chown heimdall:nogroup -L -R /var/lib/heimdall/

Run Heimdall

    systemctl start heimdalld

Check logs

    journalctl -u heimdalld.service -f

Check sync status - check [info-heimdall](./info-heimdall) 

    curl 127.0.0.1:26657/status
\

\


## Bor (req ports: 30303 tcp/udp)

Get and install the latest stable release from https://github.com/maticnetwork/bor/releases

        wget https://github.com/maticnetwork/bor/releases/download/v1.0.6/bor-v1.0.6-amd64.deb
        wget https://github.com/maticnetwork/bor/releases/download/v1.0.6/bor-mainnet-validator-config_v1.0.6-amd64.deb
        apt install ./bor-v1.0.6-amd64.deb ./bor-mainnet-validator-config_v1.0.6-amd64.deb

Download Bor snapshots (this might take days)

    tmux
    bash snapdown.sh -n mainnet -c bor -d /mnt/data/bor -t /mnt/data/bor-tmp -v true -z true -k false

Dont run Bor on boot (optional)

    systemctl disable bor





