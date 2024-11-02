#!/bin/sh

# Project root
base_dir=$2

qrencode -S -v 12 -l H -d 300 -t SVG --rle --svg-path --foreground=346751ff --background=FFFFFF00 -r $base_dir/info.txt -o $base_dir/info.svg