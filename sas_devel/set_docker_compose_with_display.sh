#!/bin/bash
set -e

open -a XQuartz
xhost + 127.0.0.1
docker compose up
