#!/usr/bin/env bash
set -euo pipefail

### Concurrency lock (prevent multiple udev-triggered runs) ###
LOCKFILE="/run/cr60_rip.lock"

exec 9>"${LOCKFILE}" || exit 0
if ! flock -n 9; then
    echo "Another CR60 rip is already running. Exiting."
    exit 0
fi

### CONFIG ###
CR60_LABEL="AUDIO"
CR60_MOUNT="/mnt/cr60"
DATA_MOUNT="/mnt/data"
MUSIC_ROOT="${DATA_MOUNT}/Music"
BEETS_DIR="${HOME}/.config/beets"
BEETS_CFG="${BEETS_DIR}/config.yaml"

### Helper: safely eject CR60 ###
eject_cr60() {
    echo "Syncing filesystem..."
    sync

    # Umount the CR60
    if mountpoint -q "${CR60_MOUNT}"; then
        echo "Unmounting ${CR60_MOUNT}..."
        sudo umount "${CR60_MOUNT}"
    fi

    # Eject the CD
    sudo eject "${CR60_DEV}"
    echo "CR60 safely ejected."
}

### Helper: shutdown if empty disk detected ###
shutdown_if_empty_disk() {
    # Find a real disk with no partitions and not swap
    EMPTY_DISK=$(lsblk -rpno NAME,TYPE,FSTYPE | awk '
        $2=="disk" && $3!="swap" {
            disk=$1
            has_partitions=0
            cmd="lsblk -rpno NAME " disk
            while ((cmd | getline) > 0) {
                if ($1 != disk) has_partitions=1
            }
            close(cmd)
            if (!has_partitions) {
                print disk
                exit
            }
        }
    ')

    if [[ -n "${EMPTY_DISK}" ]]; then
        echo "Detected closed and empty CR60 disk tray (${EMPTY_DISK} exists with no partitions)."
        echo "Shutting down system..."
        sudo shutdown -h now
    fi
}

### 1) Ensure Beets configuration exists ###
if [[ ! -f "${BEETS_CFG}" ]]; then
    echo "Creating Beets configuration at ${BEETS_CFG}..."
    mkdir -p "${BEETS_DIR}"

    cat <<'EOF' > "${BEETS_CFG}"
directory: /mnt/data/Music
library: ~/.config/beets/library.db

match:
  strong_rec_thresh: 0.90
  medium_rec_thresh: 0.90
  rec_gap_thresh: 1.0

import:
  move: yes
  write: yes
  copy: no
  autotag: yes
  timid: no
  resume: no
  quiet: yes
  from_scratch: yes
  default_action: apply

plugins:
  chroma
  fetchart
  embedart
  scrub

fetchart:
  auto: yes
  maxwidth: 1200

embedart:
  auto: yes

scrub:
  auto: yes
EOF

    chmod 600 "${BEETS_CFG}"
    echo "Beets config created successfully."
else
    echo "Beets config already exists at ${BEETS_CFG}"
fi

### 2) Wait for MusicBrainz connectivity ###
MB_URL="https://musicbrainz.org/ws/2/release/?query=barcode:0000000000000&limit=1"
echo "Waiting for MusicBrainz metadata service..."
until curl -fs --max-time 5 "${MB_URL}" >/dev/null 2>&1; do
    sleep 3
done
echo "MusicBrainz reachable."

### 3) If the CR60 disk tray is closed and empty, perform system shutdown ###
shutdown_if_empty_disk

### 4) Check for AUDIO-labeled device ###
echo "Checking for CR60 (label=${CR60_LABEL})..."
CR60_DEV=$(lsblk -rpno NAME,LABEL,TYPE | awk '$2=="'"${CR60_LABEL}"'" && $3=="part" {print $1; exit}')

if [[ -z "${CR60_DEV}" ]]; then
    echo "No device with label '${CR60_LABEL}' found. Exiting."
    exit 0
fi
echo "Found CR60 device at ${CR60_DEV}"

### 5) Mount CR60 (non-persistent) ###
sudo mkdir -p "${CR60_MOUNT}"
if ! mountpoint -q "${CR60_MOUNT}"; then
    sudo mount "${CR60_DEV}" "${CR60_MOUNT}"
fi

### 6) Check for WAV files ###
shopt -s nullglob nocaseglob
WAV_FILES=("${CR60_MOUNT}"/*.wav)

if [[ ${#WAV_FILES[@]} -eq 0 ]]; then
    echo "No WAV files found on CR60."
    eject_cr60
    exit 0
fi

### Generate GUID ###
GUID=$(uuidgen)
WORKDIR="${MUSIC_ROOT}/${GUID}"
mkdir -p "${WORKDIR}"
echo "Ripping to temporary directory: ${WORKDIR}"

### 7) Convert WAV -> FLAC ###
for wav in "${WAV_FILES[@]}"; do
    base=$(basename "${wav}")
    out="${WORKDIR}/${base%.*}.flac"

    echo "Ripping ${wav} to FLAC..."

    if ! flac --silent --best --verify --preserve-modtime -o "${out}" "${wav}"; then
        LOGFILE="${WORKDIR}/flac_error.log"
        {
            echo "FLAC verification failed"
            echo "Input WAV: ${wav}"
            echo "Output FLAC: ${out}"
            echo "Timestamp: $(date -Iseconds)"
        } >> "${LOGFILE}"
        echo "FLAC verification failed for ${wav}. Logged to ${LOGFILE}"
        eject_cr60
        exit 1
    fi

    echo "Successfully ripped ${wav} to ${out}."
done

### 8) Tagging + artwork via Beets ###
echo "Tagging files, adding art, and moving into library..."
beet import "${WORKDIR}"

### 9) Cleanup temporary directory ###
if [[ -d "${WORKDIR}" ]]; then
    flacs=("${WORKDIR}"/*.flac)
    if [[ ${#flacs[@]} -eq 0 ]]; then
        echo "No FLACs remain in ${WORKDIR}, deleting temporary workdir..."
        rm -rf "${WORKDIR}"
        sync
    fi
fi

### Done ###
shopt -u nullglob
echo "Done! Ejecting CR60..."
eject_cr60
