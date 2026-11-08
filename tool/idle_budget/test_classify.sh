#!/usr/bin/env bash
# Checks measure.sh's ffmpeg classes against saved command lines
# (testdata/argv.txt: "<class>\t<argv>", made from EncodeArgs and
# FfmpegRunner; test/idle_budget_classify_test.dart checks the live ones).
set -uo pipefail
cd "$(dirname "$0")"
fails=0
n=0
while IFS=$'\t' read -r want argv; do
  [ -z "$want" ] && continue
  n=$((n + 1))
  got=$(printf '%s\n' "$argv" | ./measure.sh --classify)
  if [ "$got" != "$want" ]; then
    echo "FAIL line $n: want $want, got $got: ${argv:0:100}"
    fails=$((fails + 1))
  fi
done < testdata/argv.txt
[ "$fails" = 0 ] && echo "PASS $n classified" || { echo "FAIL $fails of $n"; exit 1; }
