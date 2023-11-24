#!/bin/bash
########################################################################################################
# Script to automate download, verification and extraction of latest Polygon snapshots
# Author: Davide Del Grande - https://github.com/davidedg/polygon-node-notes
#  based on the original script: https://snapshot-download.polygon.technology/snapdown.sh
#   the default behaviour is retained, new functionalities must be enabled explicitly
#
# ver 12/10/2023-001
#
# Added option/functionality to:
#  - stream downloaded files directly into an extraction pipe, reducing time and required space
#  - preserve downloaded files
#  - separated temporary directory to hold downloaded and temporary data
#  - use --keep-directory-symlink in tar extraction to preserve existing symlinks, this allows to
#     pre-create symlinks pointing to slower disks for ./ancient for example
#
# If you wish to send your appreciation for this work, you can send me any token on any network:
# 0xDd288FA0D04468bEeA02F9996bc16D1Fe599D827
#
########################################################################################################

function get_abs_path() {
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

function validate_network() {
  if [[ "$1" != "mainnet" && "$1" != "mumbai" ]]; then
    echo "Invalid network input. Please enter 'mainnet' or 'mumbai'."
    exit 1
  fi
}

function validate_client() {
  if [[ "$1" != "heimdall" && "$1" != "bor" && "$1" != "erigon" ]]; then
    echo "Invalid client input. Please enter 'heimdall' or 'bor' or 'erigon'."
    exit 1
  fi
}

function validate_boolean() {
  if [[ "$1" != "true" && "$1" != "false" ]]; then
    echo "Invalid input. Please enter 'true' or 'false'."
    exit 1
  fi
}

function validate_num() {
    if [[ ! "$1" -eq "$1" ]]; then
        echo "Invalid input. Please enter a number."
        exit 1
    fi
}

function cleanup_on_exit(){
    echo "::: EXIT :::"
	if [[ -p "$FIFO" ]]; then
        rm -f $FIFO
    fi
}

########################################################################################################
# Supports multiple distros
#   RedHat RHEL/CentOS/Fedora
[[ -x /usr/bin/yum ]] && install_package="sudo yum --refresh install"                        
#   Debian 
[[ -x /usr/bin/apt-get ]] && install_package="sudo apt-get -y update && sudo apt-get install"
#   Ubuntu
[[ -x /usr/bin/apt ]] && install_package="sudo apt -y update && sudo apt install"


########################################################################################################
# install dependencies if required
NEEDS_PACKAGES=false
[[ -x $(which aria2c) ]] || NEEDS_PACKAGES=true
[[ -x $(which zstd) ]] || NEEDS_PACKAGES=true
[[ -x $(which pv) ]] || NEEDS_PACKAGES=true

$NEEDS_PACKAGES && eval $install_package zstd pv aria2

########################################################################################################
# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -n | --network)
      validate_network "$2"
      network="$2"
      shift # past argument
      shift # past value
      ;;
    -c | --client)
      validate_client "$2"
      client="$2"
      shift # past argument
      shift # past value
      ;;
    -d | --extract-dir)
      extractdir="$2"
      shift # past argument
      shift # past value
      ;;
    -t | --temp-dir)
      tempdir="$2"
      shift # past argument
      shift # past value
      ;;
    -v | --validate-checksum)
      validate_boolean "$2"
      checksum="$2"
      shift # past argument
      shift # past value
      ;;
    -z | --use-streams)
      validate_boolean "$2"
      streams="$2"
      shift # past argument
      shift # past value
      ;;
    -k | --keep-downloads)
      validate_boolean "$2"
      keepdl="$2"
      shift # past argument
      shift # past value
      ;;
    *) # unknown option
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Set default values if not provided through command-line arguments
network=${network:-mumbai}
client=${client:-heimdall}
extractdir=${extractdir:-"${client}_extract"} #"
extractdir=$(get_abs_path $extractdir)
tempdir=${tempdir:-"${client}_temp"} #"
tempdir=$(get_abs_path $tempdir)
streams=${streams:-false}
keepdl=${keepdl:-false}
if [[ "$keepdl" == "false" ]]; then
  checksum=${checksum:-true} # if download files will be deleted, enforce integrity checks by default    
else 
  checksum=${checksum:-false}
fi


########################################################################################################


# trap on cltr-c and exit signals
trap "echo ::: ABORT ::: ; exit" SIGINT
trap cleanup_on_exit SIGHUP SIGTERM EXIT

# create target and temp dirs
mkdir -p "$extractdir" || exit 2
mkdir -p "$tempdir" || exit 2


########################################################################################################
## Download all incremental files, includes automatic checksum verification per increment

function download(){
	cd "$tempdir" || exit 2 # downloads to tempdir

	if [[ ! -f "$tempdir/$client-$network-parts.txt" ]]; then 
		aria2c -x6 -s6 "https://snapshot-download.polygon.technology/$client-$network-parts.txt" || exit 2
	fi

	# remove hash lines if user declined checksum verification
	if [[ "$checksum" == "false" ]]; then
		sed -i '/checksum/d' $client-$network-parts.txt
	fi

	# download all incremental files, includes automatic checksum verification per increment
	aria2c -x6 -s6 -d $tempdir --max-tries=0 --save-session-interval=60 --save-session=$client-$network-failures.txt --max-connection-per-server=4 --retry-wait=3 --check-integrity=$checksum -i $client-$network-parts.txt

	max_retries=5
	retry_count=0

	while [ $retry_count -lt $max_retries ]; do
		echo "Retrying failed parts, attempt $((retry_count + 1))..."
		aria2c -x6 -s6 -d $tempdir --max-tries=0 --save-session-interval=60 --save-session=$client-$network-failures.txt --max-connection-per-server=4 --retry-wait=3 --check-integrity=$checksum -i $client-$network-failures.txt
		
		# Check the exit status of the aria2c command
		if [[ $? -eq 0 ]]; then
			echo "Command succeeded."
			break  # Exit the loop since the command succeeded
		else
			echo "Command failed. Retrying..."
			retry_count=$((retry_count + 1))
		fi
	done

	# Don't extract if download/retries failed.
	if [[ $retry_count -eq $max_retries ]]; then
		echo "Download failed. Restart the script to resume downloading."
		exit 1
	fi
}

download

########################################################################################################
## Join bulk/snapshot parts into valid tar.zst and extract, or extract directly if using streams

cd "$extractdir" || exit 2 # extracted data

declare -A processed_dates


# fifo to allow streaming multiple separate files directly to tar
if [[ "$streams" == "true" ]]; then
    _self="${0##*/}"
    FIFO=$(realpath ~/${_self}.fifo)
    if [[ ! -p "$FIFO" ]]; then
        mkfifo -m 600 $FIFO || exit 2
    fi
fi


## BULK
for file in $(find $tempdir -name "$client-$network-snapshot-bulk-*-part-*" -print | sort); do
    datestamp=$(echo "$file" | grep -o 'snapshot-.*-part' | sed 's/snapshot-\(.*\)-part/\1/') #"

    # Check if we have already processed this date
    if [[ -z "${processed_dates[$datestamp]}" ]]; then
        processed_dates[$datestamp]=1
        if [[ "$streams" == "true" ]]; then
			#open streamer
			tar -I zstd --keep-directory-symlink -xf - -C . < $FIFO &
			cat > $FIFO &
			DUMMYWRITER=$!
			
            for tarpart in "$tempdir"/$client-$network-snapshot-${datestamp}-part* ; do
                echo "## Extracting: $(basename $tarpart)"
                pv "$tarpart" > $FIFO
                
                # keep / delete already processed downloaded segment
                if [[ "$keepdl" == "false" ]]; then
                    echo "--- removing $tarpart ---"
                    rm -f "$tarpart"
                fi
            done
            # close streamer
            kill -9 $DUMMYWRITER >/dev/null 2>/dev/null
        else
            outputtar="$tempdir"/$client-$network-snapshot-${datestamp}.tar.zst
            echo "Join parts for ${datestamp} then extract"
            cat "$tempdir"/$client-$network-snapshot-${datestamp}-part* > "$outputtar"
            if [[ "$keepdl" == "false" ]]; then
                rm -f "$tempdir"/$client-$network-snapshot-${datestamp}-part*
            fi
            pv $outputtar | tar -I zstd -xf - -C . && rm -f $outputtar
        fi
    fi
done

## DAILY SNAPSHOTS
for file in $(find $tempdir -name "$client-$network-snapshot-*-part-*" -print | sort); do
    datestamp=$(echo "$file" | grep -o 'snapshot-.*-part' | sed 's/snapshot-\(.*\)-part/\1/') #"

    # Check if we have already processed this date
    if [[ -z "${processed_dates[$datestamp]}" ]]; then
        processed_dates[$datestamp]=1
        if [[ "$streams" == "true" ]]; then
			#open streamer
			tar -I zstd --keep-directory-symlink -xf - -C . --strip-components=3 < $FIFO &
			cat > $FIFO &
			DUMMYWRITER=$!
			
            for tarpart in "$tempdir"/$client-$network-snapshot-${datestamp}-part* ; do
                echo "## Extracting: $(basename $tarpart)"
                pv "$tarpart" > $FIFO

                # keep / delete already processed downloaded segment
                if [[ "$keepdl" == "false" ]]; then
                    echo "--- removing $tarpart ---"
                    rm -f "$tarpart"
                fi
            done
            # close streamer
            kill -9 $DUMMYWRITER >/dev/null 2>/dev/null
        else
            outputtar="$tempdir"/$client-$network-snapshot-${datestamp}.tar.zst
            echo "Join parts for ${datestamp} then extract"
            cat "$tempdir"/$client-$network-snapshot-${datestamp}-part* > "$outputtar"
            if [[ "$keepdl" == "false" ]]; then
                rm -f "$tempdir"/$client-$network-snapshot-${datestamp}-part*
            fi
            pv $outputtar | tar -I zstd -xf - -C . --strip-components=3 && rm -f $outputtar
        fi
    fi
done
