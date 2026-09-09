# Test name space util
#
# Copyright 2026 .mpe  <me@dotmpe.com>
#
# Distributed under terms of the MIT license.
. "pack_common.bash"

:expect() {
  : "${FUNCNAME[1]}"
  : "${_#test_}"
  : "${_//_/ }"
  bashunit::set_test_title "${_@Q} $1"
}

:setup-for() {
: about 'Setup unit for [ns1] module package'
: param ' ~ <Test-source> ...'
  : "${1#test/}"
  test_pack_name="${_%_test.bash}"
  pack_name1_ns1=${test_pack_name%%_*}
  pack_mod_ns1=${test_pack_name#*_}
  pack_pre_ns1=${pack_name1_ns1}_${pack111_name2["${pack_mod_ns1%%_*}"]:?}
  pack_src=src/${pack_pre_ns1}/${pack_mod_ns1}.inc
  pack_path_ns1=pack/ns1/$pack_pre_ns1/$pack_mod_ns1.bash

  #pack_mod_name_ns0=
  : "${pack_mod:=$(grep -m 1 -P '^([A-Za-z_][A-Za-z0-9_-]+)\(\)[ {]+' "$pack_src" | tr -d '() {')}"

  #declare -gn hooks=user_script_format_include__hooks
}

# Id: test_common                                vim:set ft=bash sw=2 sts=2 et:
