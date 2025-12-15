# shanling-cr60-raspberry-pi-flac-cd-ripper-and-metadata-grabber

Assumptions / prerequisites

Install these once:

sudo apt update
sudo apt install -y \
  curl \
  uuid-runtime \
  flac \
  
  musicbrainz-picard \
  eyeD3 \
  exfat-fuse exfatprogs \
  util-linux


Picard will be used in CLI mode for tagging & artwork.

The Bash script

Save as something like:

/usr/local/bin/cr60_rip.sh


Make executable:

chmod +x /usr/local/bin/cr60_rip.sh


** Add to this, to describe the partition setup for the data directory **