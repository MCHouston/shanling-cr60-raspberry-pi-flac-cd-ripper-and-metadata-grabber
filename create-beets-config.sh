#!/usr/bin/env bash
set -euo pipefail

BEETS_DIR="${HOME}/.config/beets"
BEETS_CFG="${BEETS_DIR}/config.yaml"

echo "Checking Beets configuration..."

if [[ -f "${BEETS_CFG}" ]]; then
  echo "Beets config already exists at:"
  echo "  ${BEETS_CFG}"
  echo "Nothing to do."
  exit 0
fi

echo "Creating Beets configuration..."

mkdir -p "${BEETS_DIR}"

cat <<'EOF' > "${BEETS_CFG}"
directory: /mnt/data/Music
library: ~/.config/beets/library.db

import:
  move: no
  write: yes
  copy: no
  autotag: yes
  timid: no
  resume: no
  quiet: yes
  log: ~/.config/beets/beets.log

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

echo "Beets config created successfully:"
echo "  ${BEETS_CFG}"
echo
echo "You can verify it with:"
echo "  beet config -p"
