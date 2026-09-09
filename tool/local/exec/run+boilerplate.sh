#!/usr/bin/env bash
#
# Copyright (c) 2026 .mpe  <me@dotmpe.com>
#
# Distributed under terms of the MIT license.
set -euo pipefail
shopt -s nullglob
IFS=$' \t\n'

if [[ ! ${UC_ENV_CONFIG_PID:+ne} ]]; then
  : "${US_SKELETON_DIR:=/src/local/user-scripts-template+dev}"
  PATH+=:"${US_SKELETON_DIR:?}/tool/local:${PWD}/tool/local"
  export PATH
  export UC_ETC_PATH="${PWD}/.local/etc:${US_SKELETON_DIR:?}/.local/etc:${PWD}/etc:${US_SKELETON_DIR:?}/etc"
fi

LOCAL_SEED_ENV=env.sh
LOCAL_ENV=default.bash
LLM_CONF=uc_llm_conf.bash

for var in LOCAL_{,SEED}_ENV LLM_CONF; do
  _=$( PATH=$UC_ETC_PATH \builtin command -v "${!var}" ) &&
  printf -v "${var}_FILE" '%s' "$_"
  [[ ! -s "$_" || ! -r "$_" ]] || \builtin . "$_"
  declare -x "${var}"{,_FILE}
done

\builtin . setup_common.bash
\builtin . usenv_common.bash
\builtin . env_common.bash

# us-parts config and entry-point example:

SCRIPTPATH+=:$PWD/tool/bash/part

case "${0##*/}" in
  ( run+boilerplate.* )
      :to-do "script stuff"
    ;;
esac

# Id: run+boilerplate                            vim:set ft=bash sw=2 sts=2 et:
