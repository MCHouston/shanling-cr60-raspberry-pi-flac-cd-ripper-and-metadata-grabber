#!/usr/bin/env bash
set -euo pipefail

### CONFIG ###
CR60_LABEL="AUDIO"
CR60_MOUNT="/mnt/cr60"
DATA_MOUNT="/mnt/data"
MUSIC_ROOT="${DATA_MOUNT}/Music"

### 1) Check for AUDIO-labeled device ###
echo "Checking for CR60 (label=${CR60_LABEL})..."

# Get the partition path for the connected drive(s)
CR60_DEV=$(lsblk -rpno NAME,LABEL,TYPE | awk '$2=="'"${CR60_LABEL}"'" && $3=="part" {print $1; exit}')

if [[ -z "${CR60_DEV}" ]]; then
  echo "No device with label '${CR60_LABEL}' found. Exiting."

  # TODO: Replace the following with a fill shutdown command
  exit 0
  # Later, replace this with:
  #sudo shutdown -h now
  # END TODO
fi

echo "Found CR60 device at ${CR60_DEV}"

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

  # TODO: Replace the following with a fill shutdown command
  exit 0
  # Later, replace this with:
  #sudo shutdown -h now
  # END TODO
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
  
  # Use flac library to handle conversion. Use max compression, and verify output.
  # If verification issue or another failure, write a logfile to the working directory.
  if ! flac --silent --best --verify --preserve-modtime -o "${out}" "${wav}"; then
    LOGFILE="${WORKDIR}/flac_error.log"
    {
        echo "FLAC verification failed"
        echo "Input WAV: ${wav}"
        echo "Output FLAC: ${out}"
        echo "Timestamp: $(date -Iseconds)"
    } >> "${LOGFILE}"

    echo "FLAC verification failed for ${wav}. Logged to ${LOGFILE}"

    # Shutdown if failure occurs
    sudo shutdown -h now
  fi
done

### 6) Tagging + artwork via MusicBrainz Picard ###
echo "Tagging files and pulling artwork via MusicBrainz Beets. Log error and shutdown on failure."
if ! beet import -q "${WORKDIR}" || ! beet update "${WORKDIR}"; then
    # Log both commands if they fail
    {
        beet import -q "${WORKDIR}" 2>&1
        beet update "${WORKDIR}" 2>&1
    } &> "${WORKDIR}/beets-error.log"

    echo "Beets import/update failed! See ${WORKDIR}/beets-error.log for details."
    sudo shutdown -h now
fi

# Sanitize names (replace problematic characters)
sanitize() { 
  echo "$1" | tr '/:?"<>|*\\`' '-' | tr -d '\n\t' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's/-\+/-/g'
}

### 7) Rename each FLAC track using the TITLE tag ###
FLAC_FILES=($(ls -1 "${WORKDIR}"/*.flac | sort))
counter=1
for f in "${FLAC_FILES[@]}"; do
  TITLE=$(metaflac --show-tag=TITLE "$f" | cut -d= -f2-)
  TITLE=$(sanitize "${TITLE:-Unknown Track}")

  # Use loop counter as track number
  TRACKNUM=$(printf "%02d" "$counter")
  NEWNAME="${TRACKNUM} - ${TITLE}.flac"

  mv "$f" "${WORKDIR}/${NEWNAME}"
  
  ((counter++))
done

### 8) Determine artist & album ###
ARTIST=$(metaflac --show-tag=ARTIST "${WORKDIR}"/*.flac | head -n1 | cut -d= -f2-)
ALBUM=$(metaflac --show-tag=ALBUM "${WORKDIR}"/*.flac | head -n1 | cut -d= -f2-)

ARTIST=$(sanitize "${ARTIST:-Unknown Artist}")
ALBUM=$(sanitize "${ALBUM:-Unknown Album}")

FINAL_DIR="${MUSIC_ROOT}/${ARTIST} - ${ALBUM}"

### 9) Rename directory from temp to final, handle name collisions
if [[ -d "${FINAL_DIR}" ]]; then
  i=1
  while [[ -d "${FINAL_DIR} (copy ${i})" ]]; do
    ((i++))
  done
  FINAL_DIR="${FINAL_DIR} (copy ${i})"
fi

mv "${WORKDIR}" "${FINAL_DIR}"

echo "Done!"
echo "Final directory: ${FINAL_DIR}"

### Cleanup ###
sync

# TODO: Later, add this:
#sudo shutdown -h now
# END TODO