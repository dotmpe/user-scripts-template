# Local CI run script file, for sourcing from workflows YAML but with more
# flexible tooling.
#
# Copyright (c) 2026 .mpe  <me@dotmpe.com>
#
# Distributed under terms of the MIT license.

. "env_common.bash"

# Reset caches including user-data state (for now.. TODO: CI build env finetune)
rm -rf .local/build/ .local/cache/ .local/user/data/
mkdir -vp .local/user/data >&2

redo @config @build:name:config &&
redo -j${XREDO_CORES:?} -k all

# Id: ci_run                                     vim:set ft=bash sw=2 sts=2 et:
