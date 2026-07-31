#!/usr/bin/env sh

SNAP_PATH="$(command -v snap)"

if [ -z $SNAP_PATH ]; then
  echo "Error: snap command is absent; exiting"
  exit 1
fi

sudo snap install --classic code
sudo snap install docker
