# shanling-cr60-raspberry-pi-flac-cd-ripper-and-metadata-grabber

Assumptions / prerequisites

# Installation

## APT Packages

### Install APT packages
sudo apt update
sudo apt install -y \
  curl \
  uuid-runtime \
  flac \
  python3 \
  python3-pip \
  python3-venv \
  python3-acoustid \
  beets \
  imagemagick \
  libchromaprint-tools
  



  
  // OLD, DELETE!!:

  musicbrainz-picard \ # using python version instead

  eyeD3 \
  exfat-fuse exfatprogs \
  util-linux


The Bash script

Save as something like:

/usr/local/bin/cr60_rip.sh


Make executable:

chmod +x /usr/local/bin/cr60_rip.sh


** Add to this, to describe the partition setup for the data directory **