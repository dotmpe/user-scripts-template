#
# Copyright (c) 2026 .mpe  <me@dotmpe.com>
#
# Distributed under terms of the MIT license.
us_bbb_pre=User-Script.Bare-Bone
us_bbb_fun=(
  .declare-envmaps
  .inject-env
  .load-envs
)
declare -gA \
us_bbb_als=(
  [bbb_declare]=.declare-envmaps
  [bbb_inject]=.inject-env
  [bbb_load]=.load-envs
)
declare -gA \
us_bbb_hooks=(
  [init]='
  #:cache-load ./etc/bash/us_bbb_specials.bash
  #export -f "${us_bbb_specials[@]:?}" &&
  #\builtin . "${us_bbb:?}" >&${USER_FD:?} &&
'
)

User-Script.Bare-Bone.declare-envmaps() {
: param '~ [...]'
: about 'Export special environment for build process or testing'
  declare -ga us_bbb_envs=(
    funenv-common
    dsl-common
    env-common
  )

  # FIXME: just map to use intermediate ns0 stage,
  # need :-prefix space for script/session calls
  # See us-bbb.ns0.bash for now, then later compile all this from data
  declare -gA us_bbb_dsl_common=(
    [:assert-path]=User-Script.OS.path-assert
    [:append-lookup]=User-Script.OS.lookup-append
    [:append-path]=User-Script.OS.path-append
  )
}

User-Script.Bare-Bone.inject-env() {
: param '~ [...]'
: about 'Export special environment for build process or testing'
  local -n funmap=us_bbb_${1:?} target='funmap["$fun"]'
  local fun

  [[ ${funmap[*]:+set} ]] &&
  for fun in "${!funmap[@]}"; do
    . <(printf '%s() { %s "$@"; }\n' "${fun}" "${target}")
  done
}

User-Script.Bare-Bone.load-envs() {
: param '~ <Envs...>'

  ${us_bbb_pre}declare-envmaps &&
  while (($#)); do
    local -n funmap=us_bbb_${1//-/_}
    if [[ ${funmap[*]:+set} ]]; then
      ${us_bbb_pre}inject-env "${1//-/_}" ||
        :failerr "E$? bbb injecting ${_@Q}" || return
    else
      . "$1.bash" ||
        :failerr "E$? bbb loading ${_@Q}" || return
    fi
    shift
  done
}

# Id: us-bbb                                     vim:set ft=bash sw=2 sts=2 et:
