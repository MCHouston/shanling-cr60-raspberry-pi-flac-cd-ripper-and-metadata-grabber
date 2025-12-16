#!/usr/bin/env bash
set -euo pipefail

### CONFIG ###
CR60_LABEL="AUDIO"
CR60_MOUNT="/mnt/cr60"
DATA_MOUNT="/mnt/data"
MUSIC_ROOT="${DATA_MOUNT}/Music"
BEETS_DIR="${HOME}/.config/beets"
BEETS_CFG="${BEETS_DIR}/config.yaml"

### 0) Check for AUDIO-labeled device ###
echo "Checking for CR60 (label=${CR60_LABEL})..."
CR60_DEV=$(lsblk -rpno NAME,LABEL,TYPE | awk '$2=="'"${CR60_LABEL}"'" && $3=="part" {print $1; exit}')

if [[ -z "${CR60_DEV}" ]]; then
    echo "No device with label '${CR60_LABEL}' found. Exiting."
    exit 0
fi
echo "Found CR60 device at ${CR60_DEV}"

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

### 3) Mount CR60 (non-persistent) ###
sudo mkdir -p "${CR60_MOUNT}"
if ! mountpoint -q "${CR60_MOUNT}"; then
    sudo mount "${CR60_DEV}" "${CR60_MOUNT}"
fi

### 4) Check for WAV files ###
# Ensure .wav files are discovered regardless of file type casing
shopt -s nullglob nocaseglob

# Get list of WAV files
WAV_FILES=("${CR60_MOUNT}"/*.wav)
if [[ ${#WAV_FILES[@]} -eq 0 ]]; then
    echo "No WAV files found on CR60. Exiting."
    exit 0
fi

### Generate GUID ###
GUID=$(uuidgen)
WORKDIR="${MUSIC_ROOT}/${GUID}"
mkdir -p "${WORKDIR}"
echo "Ripping to temporary directory: ${WORKDIR}"

### 5) Convert WAV -> FLAC ###
for wav in "${WAV_FILES[@]}"; do
    base=$(basename "${wav}")
    out="${WORKDIR}/${base%.*}.flac"

    if ! flac --silent --best --verify --preserve-modtime -o "${out}" "${wav}"; then
        LOGFILE="${WORKDIR}/flac_error.log"
        {
            echo "FLAC verification failed"
            echo "Input WAV: ${wav}"
            echo "Output FLAC: ${out}"
            echo "Timestamp: $(date -Iseconds)"
        } >> "${LOGFILE}"
        echo "FLAC verification failed for ${wav}. Logged to ${LOGFILE}"
        sudo shutdown -h now
    fi
done

### 6) Tagging + artwork via Beets ###
echo "Tagging files, adding art, and moving into library..."
beet import "${WORKDIR}"

### 7) Cleanup temporary directory ###
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
echo "Done! Initiating shutdown"
sync
sudo shutdown -h now
