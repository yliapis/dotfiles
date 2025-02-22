#!/user/bin/env sh

if ! command -v snap &> /dev/null; then
  echo "Error: snap command is absent; exiting"
  exit 1
fi

sudo snap install --classic code

