#!/bin/sh
orbtop --server localhost:6150 --elf-file release-build/bin/main --routines 20 --interval 1000 --cut-after=40 -p OFLOW
