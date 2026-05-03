#!/bin/bash
grep ':   ' $1 \
| sed 's/\(\w*\):  \(.*\) msecs/sail.\1    \2              # Sail \1 time (msecs)/' \
| sed 's/\(\w*\):  \(.*\) Kips/sail.\1    \2               # Sail \1 (Kips)/' \
| sed 's/\(\w*\):  \(.*\)/sail.\1    \2                    # Sail \1 /'