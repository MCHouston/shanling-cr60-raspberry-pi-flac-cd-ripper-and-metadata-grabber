# shanling-cr60-raspberry-pi-flac-cd-ripper-and-metadata-grabber

This project allows you to automatically rip audio CDs using a Shanling CR60, convert the WAVs to FLAC, tag them using Beets and MusicBrainz, and store them in a structured music library on a Raspberry Pi.

---

## Assumptions / Prerequisites

- Raspberry Pi with a USB port, running a Debian-based Linux (e.g., Raspberry Pi OS).
- Shanling CR60 CD transport connected via USB.
- A storage drive mounted at `/mnt/data`, ideally formatted as **exFAT**, intended to store your music library at `/mnt/data/Music`.
- Internet access to reach MusicBrainz for metadata.

---

## Installation

### 1) Install APT packages

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

### 2) Save the Bash script

Save the script as:

```
/opt/cr60_rip/cr60_rip.sh
```

Make it executable:

```bash
sudo chmod 700 /opt/cr60_rip/cr60_rip.sh
sudo chown root:root /opt/cr60_rip/cr60_rip.sh
```

---

### 3) Beets Configuration

The script automatically creates a Beets configuration at `~/.config/beets/config.yaml` if it does not exist.  

Key settings:

- Library stored at `~/.config/beets/library.db`
- Music directory: `/mnt/data/Music`
- Autotagging enabled
- Move and write tags to imported files
- Plugins: `chroma`, `fetchart`, `embedart`, `scrub`
- Quiet mode enabled for automatic processing

---

### 4) Data Partition Setup

Mount the data partition as `/mnt/data`.
- Ensure that it has been added to the linux fstab, so that the mount persists on system reboots.
- Ensure root has write permissions on `/mnt/data` (script runs as root).

---

### 5) Systemd Service & Timer Setup

This setup runs the ripper automatically every minute. If the CR60 is not connected, nothing happens. When the CR60 is connected, the script runs.

#### 5a) Service

Create `/etc/systemd/system/cr60_rip.service`:

```ini
[Unit]
Description=Shanling CR60 FLAC Ripper Service
After=network.target

[Service]
Type=oneshot
ExecStart=/opt/cr60_rip/cr60_rip.sh
User=root
```

#### 5b) Timer

Create `/etc/systemd/system/cr60_rip.timer`:

```ini
[Unit]
Description=Run Shanling CR60 FLAC Ripper every minute

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
Unit=cr60_rip.service

[Install]
WantedBy=timers.target
```

#### 5c) Enable and start the timer

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now cr60_rip.timer
sudo systemctl start cr60_rip.timer
```

#### 5d) Check timer status

```bash
systemctl status cr60_rip.timer
systemctl list-timers | grep cr60_rip
```

---

## Usage

- Connect the Shanling CR60 via USB
- Insert an audio CD
- The systemd timer will detect the device and run the script automatically
- The script will:
  1. Detect the device
  2. Convert WAVs to FLAC in a temporary directory
  3. Tag files and fetch artwork
  4. Move tagged FLACs to `/mnt/data/Music`
  5. Delete the temporary directory
  6. Shutdown the Raspberry Pi after processing

---

## Notes

- Ensure `/mnt/data` has sufficient free space for FLAC files.
- The Pi will shutdown automatically after processing.
- To override quiet mode or change Beets settings, edit `~/.config/beets