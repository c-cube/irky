#!/bin/sh
OPTS="--profile=release --display=quiet"
exec dune exec $OPTS -- examples/example.exe $@
