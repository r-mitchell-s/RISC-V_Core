#!/bin/bash
docker run -it --rm -v "$(pwd)":/work -w /work ebmc "$@"