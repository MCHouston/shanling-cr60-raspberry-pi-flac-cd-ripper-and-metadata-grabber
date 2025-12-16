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

### 5) Systemd Service & udev Event-Driven Setup

This setup runs the ripper automatically when the Shanling CR60 CD device
appears (for example, when a CD is inserted or the device powers on).

This approach is event-driven, running
only when the hardware appears.

---

#### 5a) Systemd Service

Create `/etc/systemd/system/cr60_rip.service`:

```ini
[Unit]
Description=Shanling CR60 FLAC Ripper Service
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/opt/cr60_rip/cr60_rip.sh
User=root
```

#### 5b) udev Rule

Create `/etc/udev/rules.d/99-cr60.rules`:

```ini
SUBSYSTEM=="block", KERNEL=="sd[a-z]", ACTION=="add", TAG+="systemd", \
  ENV{SYSTEMD_WANTS}="cr60_rip.service"
```

This rule tells udev:

- Watch for block devices (`SUBSYSTEM=="block"`)
- Match the top-level USB storage device exposed by the CR60 (`sd[a-z]`)
- When the device appears (`ACTION=="add"`)
- Tag the device for systemd handling (`TAG+="systemd"`)
- Ask systemd to start `cr60_rip.service`

#### 5c) Reload udev and systemd

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
sudo systemctl daemon-reload
```

#### 5d) Monitoring & Debugging

```bash
# View log output from the cr60_rip.service service:
sudo journalctl -u cr60_rip.service -f
# Watch udev events in real time:
sudo udevadm monitor --subsystem-match=block
```

##### Concurrency Safety

Because udev can emit multiple events, the rip script uses a lock file
(e.g. `flock`) to guarantee only one rip runs at a time.

---

## Usage

- Connect the Shanling CR60 via USB
- Insert an audio CD
- The udev rule will detect when a new drive appears (CR60) and trigger the cr60_rip.service
- The script will:
  1. Detect the CD in the CR60 disk tray (CR60 must be in rip mode, connected via it's USB-B port to the raspberry pi)
  2. Rip WAVs off of the CD to lossless FLAC in a temporary directory
  3. Tag files and fetch artwork
  4. Move tagged FLACs to `/mnt/data/Music`
  5. Delete the temporary directory (if it still exists)
  6. Eject the CR60 disk tray
  7. Shut down the raspberry pi once the disk tray is closed with no CD in it, or begin ripping the next CD if a new disk is loaded

---

## Notes

- Ensure `/mnt/data` has sufficient free space for FLAC files.
- The Pi will shutdown automatically after processing.
- To override quiet mode or change Beets settings, edit `~/.config/beets