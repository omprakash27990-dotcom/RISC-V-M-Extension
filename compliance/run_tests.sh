#!/usr/bin/env bash
set -u
ARCH=~/compliance_test/riscv-arch-test
SIM=~/compliance_test/sim/obj_dir/Vrv32i_soc_top
OUT=~/compliance_test/sim/results
EXTS="I M"
mkdir -p "$OUT"
PASS=0; FAIL=0; SKIP=0

for ext in $EXTS; do
  for elf in "$ARCH"/work/mycore-RVI20U32/build/rv32i/$ext/*.sig.elf; do
    name=$(basename "$elf" .sig.elf)
    gold="$ARCH/work/mycore-RVI20U32/build/rv32i/$ext/${name}.sig"
    [ -f "$gold" ] || gold="$ARCH/work/sail-RVI20U32/build/rv32i/$ext/${name}.sig"
    [ -f "$gold" ] || { echo "SKIP (no golden sig): $ext/$name"; SKIP=$((SKIP+1)); continue; }

    syms=$(riscv-none-elf-nm "$elf")
    begin=$(echo "$syms" | awk '/ begin_signature$/{print $1}')
    end=$(echo "$syms"   | awk '/ end_signature$/{print $1}')
    tohost=$(echo "$syms" | awk '/ D tohost$/{print $1}')

    mine="$OUT/${ext}_${name}.sig"
    rm -f "$mine"
    "$SIM" "$elf" "$mine" "$begin" "$end" "$tohost" 2000000 2> "$OUT/${ext}_${name}.log"
    rc=$?

    if [ $rc -ne 0 ]; then
      case $rc in
        1) why="simulator error (load/IO)";;
        2) why="timeout, no tohost write";;
        3) why="test reported failure via tohost";;
        *) why="exit code $rc";;
      esac
      echo "FAIL: $ext/$name  [$why]  (see $OUT/${ext}_${name}.log)"; FAIL=$((FAIL+1)); continue
    fi
    if [ ! -s "$mine" ]; then
      echo "FAIL: $ext/$name  [empty signature]"; FAIL=$((FAIL+1)); continue
    fi
    if diff -q "$gold" "$mine" > /dev/null 2>&1; then
      echo "PASS: $ext/$name"; PASS=$((PASS+1))
    else
      echo "FAIL: $ext/$name  [signature mismatch]  (see $OUT/${ext}_${name}.log)"; FAIL=$((FAIL+1))
    fi
  done
done
echo; echo "=== $PASS passed, $FAIL failed, $SKIP skipped ==="
[ $FAIL -eq 0 ] && [ $SKIP -eq 0 ]
