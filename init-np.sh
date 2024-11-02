#!/bin/sh

np=$1
size=$2

# Project root
base_dir="$(dirname "$(readlink -f "$0")")"

# Clean-up the tmp
rm $base_dir/tmp/*