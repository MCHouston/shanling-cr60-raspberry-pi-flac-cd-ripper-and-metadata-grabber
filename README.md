# shanling-cr60-raspberry-pi-flac-cd-ripper-and-metadata-grabber

Assumptions / prerequisites

# Installation

## APT Packages

### Install snapd
sudo apt update
sudo apt install -y snapd
//sudo systemctl enable --now snapd.socket //Lkely Not needed
//sudo ln -s /var/lib/snapd/snap /snap // Likely not needed
sudo reboot

### Install APT packages
sudo apt update
sudo apt install -y \
  snapd \
  curl \
  uuid-runtime \
  flac \
  



  
  // OLD, DELETE!!:

  musicbrainz-picard \ # using python version instead

  eyeD3 \
  exfat-fuse exfatprogs \
  util-linux


### Install Picard from Snapcraft, and ensure it has access to removable media (persists)
sudo snap install core
sudo snap install picard
snap connect picard:removable-media


# Running the script
Picard will be used in CLI mode for tagging & artwork.

The Bash script

Save as something like:

/usr/local/bin/cr60_rip.sh


Make executable:

chmod +x /usr/local/bin/cr60_rip.sh


** Add to this, to describe the partition setup for the data directory **