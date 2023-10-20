# polygon-node-notes
Notes on building a Polygon node on Debian

If you wish to send your appreciation for this work, you can send me any token on any network:
0xDd288FA0D04468bEeA02F9996bc16D1Fe599D827

\
Download the snapshot downloader script:

    wget https://github.com/davidedg/polygon-node-notes/raw/main/snapdown.sh

## Heimdall (req ports: 26656 tcp)

Get and install the latest stable release from https://github.com/maticnetwork/heimdall/releases

    wget https://github.com/maticnetwork/heimdall/releases/download/v1.0.2/heimdalld-v1.0.2-amd64.deb
    wget https://github.com/maticnetwork/heimdall/releases/download/v1.0.2/heimdalld-mainnet-sentry-config_v1.0.2-amd64.deb
    apt install ./heimdalld-v1.0.2-amd64.deb ./heimdalld-mainnet-sentry-config_v1.0.2-amd64.deb
        
Dont run Heimdall on boot (optional)

    systemctl disable heimdalld

\
Download Heimdall snapshots (this might take hours)

    tmux
    bash snapdown.sh -n mainnet -c heimdall -d /mnt/data/heimdall -t /mnt/data/heimdall-tmp -v true -z true -k false

\
Edit the unit definition if required (e.g.: change User to root or change the "--chain=mainnet" - but for this you'd be better off with starting with a different profile deb)

    systemctl edit heimdalld.service
    systemctl daemon-reload

\
Use a pre-populated address book file ( [example](./addrbook.json) ), put it under `/var/lib/heimdall/config/`

\
Changes to `/var/lib/heimdall/config/config.toml`

    laddr = "tcp://127.0.0.1:26657"

  - change to 0.0.0.0 if needed - this port does not need be published to the Internet.

  - configure list of initial nodes (seeds) - get them from https://wiki.polygon.technology/docs/pos/operate/node/full-node-binaries/#configure-heimdall-seeds-mainnet

        sed -i 's|^seeds\s*=.*|seeds = "1500161dd491b67fb1ac81868952be49e2509c9f@52.78.36.216:26656,dd4a3f1750af5765266231b9d8ac764599921736@3.36.224.80:26656,8ea4f592ad6cc38d7532aff418d1fb97052463af@34.240.245.39:26656,e772e1fb8c3492a9570a377a5eafdb1dc53cd778@54.194.245.5:26656,6726b826df45ac8e9afb4bdb2469c7771bd797f1@52.209.21.164:26656"|g' /var/lib/heimdall/config/config.toml

  - set the public ip address (if under NAT)

        external_address = "1.2.3.4"

\
Symlink the downloaded heimdall snaphot to data directory

    mv /var/lib/heimdall/data /var/lib/heimdall/data-orig && sudo -u heimdall  ln -s /mnt/data/heimdall /var/lib/heimdall/data 

Reset permissions to heimdall user (mind the `-L` switch !) and check that no other files are not owned by heimdall

    chown heimdall:nogroup -L -R /var/lib/heimdall/
    find -L /var/lib/heimdall/ -not -user heimdall

Run Heimdall

    systemctl start heimdalld

Check logs

    journalctl -u heimdalld.service -f

Check sync status - check [info-heimdall](./info-heimdall) 

    curl 127.0.0.1:26657/status

  - Do not start bor until Heimdall is synced! (curl localhost:26657/status - catching_up = false !)


## Bor (req ports: 30303 tcp/udp)

Get and install the latest stable release from https://github.com/maticnetwork/bor/releases

    wget https://github.com/maticnetwork/bor/releases/download/v1.0.6/bor-v1.0.6-amd64.deb
    wget https://github.com/maticnetwork/bor/releases/download/v1.0.6/bor-mainnet-sentry-config_v1.0.6-amd64.deb
    apt install ./bor-v1.0.6-amd64.deb ./bor-mainnet-sentry-config_v1.0.6-amd64.deb

Dont run Bor on boot (optional)

    systemctl disable bor

\
Download Bor snapshots (this might take days)

    tmux
    bash snapdown.sh -n mainnet -c bor -d /mnt/data/bor -t /mnt/data/bor-tmp -v true -z true -k false

Generate a new config.toml in `/var/lib/bor/config.toml`

    mv /var/lib/bor/config.toml /var/lib/bor/config-default-sentry.toml && bor dumpconfig > /var/lib/bor/config.toml

\
Changes to `/var/lib/bor/config.toml`

  - Change datadir

        sed -i 's|^datadir\s*=.*|datadir = "/var/lib/bor/data"|g' /var/lib/bor/config.toml


  - Enable HTTP, WS, IPC endpoints

        sed -i 's|ipcdisable\s*=.*|ipcdisable = false|g' /var/lib/bor/config.toml
        sed -i 's|ipcpath\s*=.*|ipcpath = "bor.ipc"|g' /var/lib/bor/config.toml

        [jsonrpc.http]
          enabled = true
          host = "0.0.0.0"
          api = ["eth", "net", "web3", "txpool", "bor"]

        [jsonrpc.ws]
          enabled = true
          host = "0.0.0.0"
          api = ["eth", "net", "web3", "txpool", "bor"]

  - Review recent recommended settings: https://forum.polygon.technology/t/recommended-peer-settings-for-mainnet-nodes/13018#bor-2

        [p2p]
        maxpeers = 50

        [p2p.discovery]
        bootnodes = ["enode://76316d1cb93c8ed407d3332d595233401250d48f8fbb1d9c65bd18c0495eca1b43ec38ee0ea1c257c0abb7d1f25d649d359cdfe5a805842159cfe36c5f66b7e8@52.78.36.216:30303", "enode://b8f1cc9c5d4403703fbf377116469667d2b1823c0daf16b7250aa576bacf399e42c3930ccfcb02c5df6879565a2b8931335565f0e8d3f8e72385ecf4a4bf160a@3.36.224.80:30303", "enode://8729e0c825f3d9cad382555f3e46dcff21af323e89025a0e6312df541f4a9e73abfa562d64906f5e59c51fe6f0501b3e61b07979606c56329c020ed739910759@54.194.245.5:30303", "enode://681ebac58d8dd2d8a6eef15329dfbad0ab960561524cf2dfde40ad646736fe5c244020f20b87e7c1520820bc625cfb487dd71d63a3a3bf0baea2dbb8ec7c79f1@34.240.245.39:30303"]

  - (optional) Increase resources (review num of procs)

        [cache]
          cache = 4096
          triesinmemory = 256

        [parallelevm]
          enable = true
          procs = 8

  - (optional) Enable telemetry

        [telemetry]
          metrics = true

\
Create data structure and symlink the snapshot chaindata (see also [bor-alternative.md](./bor-alternative.md))

    [[ -s /mnt/data/bor/bor/chaindata ]] && rm /mnt/data/bor/bor/chaindata
    
    mkdir -p /var/lib/bor/data/bor
	ln -s /mnt/data/bor/ /var/lib/bor/data/bor/chaindata
	ln -s /mnt/data/bor/bor/nodes /var/lib/bor/data/bor/nodes
	ln -s /mnt/data/bor/bor/triecache /var/lib/bor/data/bor/triecache

	tree -d /var/lib/bor/
		/var/lib/bor/
		└── data
		    ├── bor
		    │   ├── chaindata -> /mnt/datassd/bor/chaindata
		    │   ├── nodes -> /mnt/data/bor/bor/nodes
		    │   └── triecache -> /mnt/data/bor/bor/triecache
		    └── keystore
	


Download the mainnet bor genesis file

    curl -o /var/lib/bor/data/genesis.json 'https://raw.githubusercontent.com/maticnetwork/bor/master/builder/files/genesis-mainnet-v1.json'

\
Reset permissions to bor user (mind the `-L` switch !) and check that no other files are not owned by bor

    chown bor:nogroup -L -R /var/lib/bor/
    find -L /var/lib/bor/ -not -user bor

Run Bor (double check that heimdall is in sync!)

    systemctl start bor

Check logs

    journalctl -u bor.service -f
