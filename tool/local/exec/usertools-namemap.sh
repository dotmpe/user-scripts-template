#!/usr/bin/env bash
# Usage: ./namemap.sh [module_and_package_namemap.yaml]
# Requires: mikefarah/yq v4

set -euo pipefail
YAML="${1:?Input YAML document required}"
YQ="${YQ:-yq}"

: "${PACK_PREF:=PACKAGE_}"
: "${MOD_PREF:=MODULE_}"
: "${FWDKEY:-FWD}"
: "${BWDKEY:-BWD}"

DTSTART=$(date --iso=sec)
SCRNAME=${0##*/}
echo "# Generator: ${SCRNAME##*/} $$"
echo "# Source document: ${YAML##*/}"
echo

# ---------- PACKAGE maps ----------
# Forward: canonical package name → space-separated list of *all* terms (canonical + aliases)
# Backward: every term → canonical package name

echo "# ===== package maps ====="
echo "declare -gA ${PACK_PREF}${FWDKEY}=("
$YQ -r '
  .package
  | to_entries[]
  | .key as $canon
  | ($canon + " " + (.value | join(" "))) as $all
  | "  [\"" + $canon + "\"]=\"" + $all + "\""
' "$YAML"
echo ")"

echo
echo "declare -gA ${PACK_PREF}${BWDKEY}=("
$YQ -r '
  .package
  | to_entries[]
  | .key as $canon
  | ([$canon] + .value)[]
  | "  [\"" + . + "\"]=\"" + $canon + "\""
' "$YAML"
echo ")"

# ---------- MODULE maps ----------
# Modules are nested under a parent package (User-Scripts).
# We flatten the key to "Parent.Module" (e.g. User-Scripts.Shell)
# Forward: "Parent.Module" → space-separated list of all terms
# Backward: every term → "Parent.Module"

echo
echo "# ===== module maps ====="
echo "declare -gA ${MOD_PREF}${FWDKEY}=("
$YQ -r '
  .module
  | to_entries[]
  | .key as $parent
  | .value
  | to_entries[]
  | .key as $mod
  | ($parent + "." + $mod) as $full
  | ($full + " " + (.value | join(" "))) as $all
  | "  [\"" + $full + "\"]=\"" + $all + "\""
' "$YAML"
echo ")"

echo
echo "declare -gA ${MOD_PREF}${BWDKEY}=("
$YQ -r '
  .module
  | to_entries[]
  | .key as $parent
  | .value
  | to_entries[]
  | .key as $mod
  | ($parent + "." + $mod) as $full
  | ([$full] + .value)[]
  | "  [\"" + . + "\"]=\"" + $full + "\""
' "$YAML"
echo ")"

echo
echo "# Generated at $DTSTART"
