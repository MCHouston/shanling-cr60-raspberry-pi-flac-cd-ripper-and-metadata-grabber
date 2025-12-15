# shanling-cr60-raspberry-pi-flac-cd-ripper-and-metadata-grabber

Assumptions / prerequisites

# Installation

### APT Packages
sudo apt update
sudo apt install -y \
  curl \
  uuid-runtime \
  flac \
  libchromaprint1 \
  libchromaprint-tools \
  gettext \
  git \
  python3 \
  python3-pip \
  python3-venv \
  python3-mutagen \
  python3-requests
  



  
  // OLD, DELETE!!:

  musicbrainz-picard \ # using python version instead

  eyeD3 \
  exfat-fuse exfatprogs \
  util-linux

## Python virtual environment setup for picard

### Create virtual environment for Picard Tools
sudo python3 -m venv /opt/picard-cli

### Activate venv
source /opt/picard-cli/bin/activate

### Install AcoustID + Picard Tools (headless Picard)
git clone https://github.com/metabrainz/picard.git /opt/picard-src
pip install /opt/picard-src --no-deps
pip install mutagen requests pyacoustid PyYAML

### Exit venv
deactivate





# Running the script
Picard will be used in CLI mode for tagging & artwork.

The Bash script

Save as something like:

/usr/local/bin/cr60_rip.sh


Make executable:

chmod +x /usr/local/bin/cr60_rip.sh


** Add to this, to describe the partition setup for the data directory **