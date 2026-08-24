#!/bin/bash
# 格子収束の検証。本番と同一の config.json / tsv_config.json をそのまま使い、
# 格子だけ 240 -> 480 に上げる。出力は snapshot_g480.jld2（本番の snapshot.jld2 は触らない）。
# 対象4設計は N=48 の Tmax 範囲を等分して選んだもの（tmax_n48.tsv 参照）。
set -u
ROOT=/home/foo/somad_dev3
HERE="$(cd "$(dirname "$0")" && pwd)"
NX="${NX:-480}"; PAR="${PAR:-4}"; TAG="${TAG:-g480}"
CASES="${CASES:-n48_012 n48_007 n48_113 n48_015}"
run_one(){
  name="$1"; d="$HERE/cases/$name"
  out="$d/snapshot_${TAG}.jld2"; [ -f "$out" ] && { echo "skip  $name"; return 0; }
  wd="$d/$TAG"; mkdir -p "$wd"; cp "$d/config.json" "$d/tsv_config.json" "$wd/"
  s=$(date +%s)
  ( cd "$wd" && GKSwstype=nul julia --project=$ROOT/H2-main-ext $ROOT/H2-main-ext/run.jl \
      "$NX" "$NX" 30 pbicgstab gs 1e-4 sequential true \
      --cooled-face zplus --h-sink 151000 --h-weak 0 --fix-convection-rhs \
      --snapshot "$out" > run.log 2>&1 )
  [ -f "$out" ] && echo "ok    $name  $(( $(date +%s)-s ))s" || { echo "FAIL  $name"; tail -5 "$wd/run.log"; }
}
export -f run_one; export ROOT HERE NX TAG
echo "=== $TAG start $(date -Is) : $PAR workers, NX=$NX, cases: $CASES ==="
printf '%s\n' $CASES | xargs -P "$PAR" -I{} bash -c 'run_one "$@"' _ {}
n=$(find "$HERE/cases" -name "snapshot_${TAG}.jld2" | wc -l)
echo "=== $TAG end $(date -Is) : $n/$(printf '%s\n' $CASES | wc -l) ==="
