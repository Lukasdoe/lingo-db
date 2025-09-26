#!/usr/bin/env bash
set -euo pipefail
TMPDIR=`mktemp --directory`
echo $TMPDIR
pushd $TMPDIR
git clone https://github.com/lingo-db/ssb-dbgen.git
cmake -B . ssb-dbgen && cmake --build .
SF=$2
./dbgen -f -T c -s "$SF"
./dbgen -qf -T d -s "$SF"
./dbgen -qf -T p -s "$SF"
./dbgen -qf -T s -s "$SF"
./dbgen -q -T l -s "$SF"
chmod +r *.tbl
for table in ./*.tbl; do
  # sed behaves differently on macOS and linux. Currently, there is no stable, portable command that works on both.
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' 's/|$//' "$table"  # macOS
  else
    sed -i 's/|$//' "$table"     # Linux
  fi
for table in ./*.tbl; do mv "$table" "$1/$table"; done
popd
