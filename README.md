# shanling-cr60-raspberry-pi-flac-cd-ripper-and-metadata-grabber

Assumptions / prerequisites

Install these once:

sudo apt update
sudo apt install -y \
  flac \
  musicbrainz-picard \
  eyeD3 \
  uuid-runtime \
  exfat-fuse exfatprogs \
  curl \
  util-linux


Picard will be used in CLI mode for tagging & artwork.

The Bash script

Save as something like:

/usr/local/bin/cr60_rip.sh


Make executable:

chmod +x /usr/local/bin/cr60_rip.sh