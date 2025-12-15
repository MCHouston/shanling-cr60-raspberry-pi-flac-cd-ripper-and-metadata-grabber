# shanling-cr60-raspberry-pi-flac-cd-ripper-and-metadata-grabber

This project allows you to automatically rip audio CDs using a Shanling CR60, convert the WAVs to FLAC, tag them using Beets and MusicBrainz, and store them in a structured music library on a Raspberry Pi.

## Assumptions / Prerequisites

- Raspberry Pi with a USB port, running a Debian-based Linux (e.g., Raspberry Pi OS).
- Shanling CR60 CD transport connected via USB.
- A storage drive mounted at `/mnt/data` ideally formatted as **exFAT**, intended to store your music library at /mnt/data/Music.
- Internet access to reach MusicBrainz for metadata.

## Installation

### APT Packages

Update your package list and install required packages:
```bash
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
```

## The Bash Script

Save the script as `/usr/local/bin/cr60_rip.sh` and make it executable:
```bash
chmod +x /usr/local/bin/cr60_rip.sh
```

The script will:
1. Detect if the Shanling CR60 device is connected (ex. via USB).
2. Wait for MusicBrainz connectivity.
3. Mount the CR60.
4. Convert WAV files to FLAC in a temporary directory.
5. Tag files and fetch artwork using Beets.
6. Move tagged FLACs into the structured library at `/mnt/data/Music`.
7. Delete the temporary working directory.
8. Shutdown the Pi when done.

## Beets Configuration

The script automatically creates a Beets configuration at `~/.config/beets/config.yaml` if it does not exist. Key settings:
- Library stored at `~/.config/beets/library.db`.
- Music directory: `/mnt/data/Music`.
- Autotagging enabled.
- Move and write tags to imported files.
- Plugins: `chroma`, `fetchart`, `embedart`, `scrub`.
- Quiet mode enabled for automatic processing.

## Usage

Insert an audio CD into the CR60, connect the CR60 to the Raspberry Pi via USB, and run:
```bash
sudo /usr/local/bin/cr60_rip.sh
```
The script will handle ripping, conversion, tagging, and moving the files to your music library.

## Notes

- Ensure `/mnt/data` has sufficient free space for FLAC files.
- The Pi will shutdown automatically after processing.
- To override quiet mode or change Beets settings, edit `~/.conf