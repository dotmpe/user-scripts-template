#!/usr/bin/env bash
#
# configure.sh - Configure (existing or new) worktree from template project
#
# The canonical source of this script exists at configure+skeleton.bash; the
# local file may be a copy or derived version[*].
#
# [*] See +User-Scripts-Template's base skeleton
#   <https://github.com/user-tools/user-scripts-template>
#
# Copyright (c) 2026 .mpe  <me@dotmpe.com>
#
# Distributed under terms of the MIT license.
#
set -eETuCo pipefail
shopt -s failglob
IFS=$' \t\n'

# Provision to set (override) any env/variable assignment from arguments, using `declare`
declare -ga env_{export,overrides}
while [[ ${1:+set} && ${1} == *=* ]]; do
  \builtin declare "$1"
  env_overrides+=( "${1%%=*}" )
  shift
done

# Provision to source local script, to seed/preinit from local project settings
for US_LOCAL_ENV in \
  "${US_LOCAL_ENV:-./.env.sh}" \
  .local/etc/env.bash \
  etc/env.bash
do [[ -e "$US_LOCAL_ENV" ]] || continue
  \builtin . "$US_LOCAL_ENV"
done

# Determine context: get skeleton dir, configure script's name plus tag

if [[ $0 == /dev/stdin || $0 == bash ]]; then
  : "${US_CONFIGURE_SCRIPT:=configure+skeleton}"
else
  : "${0##*/}"
  US_CONFIGURE_SCRIPT="${_%.bash}"
fi

: "${GIT_TEMPLATE_REPOSITORY:=dotmpe/user-scripts-template}"
if [[ $0 = */"$GIT_TEMPLATE_REPOSITORY"[+/.]* ]]; then
  : 'can use base directory from current script directly'
  US_SKELETON_DIR=${0%"$US_CONFIGURE_SCRIPT"*}
else
  : 'default builtin values only'
  : "${GIT_TEMPLATE_REPOSITORY#*/}"
  : "${US_SKELETON_DIR:=/src/local/${_:?}+dev}"
fi

if [[ ! -d $US_SKELETON_DIR ]]; then
  >&2 echo "No template project to copy from (none found at ${US_SKELETON_DIR@Q})"
  exit 2
fi

for etc in .local/etc etc; do
  [[ -d "./$etc/" ]] && uc_etc_path+=( "$PWD/$etc" )
  etc=$US_SKELETON_DIR/$etc
  [[ -d "$etc/" ]] && uc_etc_path+=( "$etc" )
done; unset etc
IFS=:; UC_ETC_PATH=${uc_etc_path[*]}; IFS=$' \t\n'

if [[ ! -e "$US_LOCAL_ENV" ]]; then
  US_LOCAL_ENV=$(PATH=$UC_ETC_PATH \builtin command -v env.bash) || {
    >&2 cp -v "$US_SKELETON_DIR"/etc/bash/ci_env.github.bash .local/etc/env.bash &&
    US_LOCAL_ENV=$PWD/.local/etc/env.bash; } &&
  \builtin . "$US_LOCAL_ENV" || {
    stat=$?
    >&2 echo "There is no US_LOCAL_ENV=${US_LOCAL_ENV@Q}"
    exit $stat
  }
fi

env_exports+=( US_LOCAL_ENV UC_ETC_PATH )

# Provision to update current script, or use canonical script.
# To just install just this file and keep it up to date
# - copy and remove the standard +skeleton tag from the name, or
# - TODO: same as copy but using symlink, or
# - run from stream or pipe:
#
#   bash -- configure.bash < .../configure+skeleton.bash
#

if [[ ${US_CONFIGURE_SCRIPT%%+*} == configure ]]; then
  : 'standard deployment rules'
  US_CONFIGURE_SCRIPT_TAG="${US_CONFIGURE_SCRIPT#*+}"
  case " ${US_CONFIGURE_SCRIPT_TAG//[!A-Za-z0-9_]/ } " in
    ( *" skeleton "* )
        : 'local tag + "skeleton": update copy to template version'

        # Strip +skeleton tag now
        US_CONFIGURE_NEW="$US_SKELETON_DIR/configure+skeleton.bash"
        US_CONFIGURE_LOCAL="./${US_CONFIGURE_SCRIPT/+skeleton}.bash"
        : "${US_CONFIGURE_SCRIPT_TAG/+skeleton}"
        US_CONFIGURE_SCRIPT="./configure${_:+"+$_"}"

        [[ -z "${US_CONFIGURE_LOCAL%/*}" ]] || mkdir -vp "${US_CONFIGURE_LOCAL%/*}"

        : "$US_CONFIGURE_LOCAL"
        if ! test -e "$_"; then cp "$US_CONFIGURE_NEW" "$_"

        elif ! test -h "$_" &&
            ! diff -bqr "$US_CONFIGURE_NEW" "./$_" >/dev/null; then

          # Update configure.sh from configure+skeleton.sh and respawn this script
          printf -v cmd 'cp "%s" "%s" && exec bash "%s"' "$US_CONFIGURE_NEW" "$_" "$_"
          exec bash -c "$cmd"
          # TODO: add current script arguments as well to above fork

        elif test -h "$_"; then

          TODO
        fi
      ;;

    ( * )
      : 'with other local tag, do nothing for now'
        # probably use some assoc mapping, tag expressions to configure
        # behavior:
        # - symlink may be to configure.bash in template?
        # - copy and remove configure.bash, or never copy at all?
        # - want to cover curl-pipe scenarios as well
      ;;
  esac
else
  : 'non-standard deployment, continue'
fi

# Start the actual configuration process
#

for US_TEMPLATE_CONFIG in \
  "${US_TEMPLATE_CONFIG:-etc/user_script_template.bash}" \
  .local/etc/user_script_template.bash \
  "$US_SKELETON_DIR"/etc/user_script_template.bash
do [[ -e "$US_TEMPLATE_CONFIG" ]] || continue; done
\builtin . "$US_TEMPLATE_CONFIG"

#shellcheck disable=2154
for file in "${us_skeleton_copy[@]}"; do
  us_src="$US_SKELETON_DIR/${file}"
  if [[ ! -e $us_src ]]; then
    >&2 echo "No template source ${us_src}"
    exit 1
  else
    if [[ ! -s $file ]]; then
      >&2 mkdir -vp "${file%/*}" &&
      >&2 cp -v "$us_src" "./${file}"
    fi
  fi
done

#shellcheck disable=2154
for file in "${us_skeleton_symlink[@]}"; do
  us_src="$US_SKELETON_DIR/${file}"
  if [[ ! -e $us_src ]]; then
    >&2 echo "No template source ${us_src}"
    exit 1
  else
    if [[ ! -e ${file} ]]; then
      if [[ -h ${file} ]]; then rm "$file" || exit; fi
      >&2 mkdir -vp "${file%/*}" &&
      >&2 ln -s "$us_src" "$file"
    fi
  fi
done
unset file us_src

# Configure project
: "${GIT_ORIGIN_URL:-$(git config --get remote.${GIT_REMOTE:-origin}.url)}"
: "${_#"${GIT_ORIGIN_NETPATH:-git@github.com:}"}"
GIT_PROJECT_REPOSITORY=${_%.git}

local_template_env_vars=(
  GIT_TEMPLATE_REPOSITORY
  GIT_PROJECT_REPOSITORY
  US_SKELETON_DIR
)

# Configure Redo (project build targets)

if [[ ! -e ${XREDO_CONFIG:=.local/etc/xredo_default.bash} ]]; then

  xredo_all_targets=( @config )
  xredo_build_targets=( )

  : "${usertools_namemap_name:="usertools_package_namemap.bash"}"
  usertools_namemap=.local/var/$_
  US_NS_STATE=$usertools_namemap
  : "$PWD/schema:$US_SKELETON_DIR/schema"
  PACKAGE_NAMEMAP_YAML=$(PATH=$_ \builtin command -v "${usertools_namemap_name%.bash}.yaml")

  if [[ -e $PACKAGE_NAMEMAP_YAML ]]; then
    xredo_build_targets+=( @build:name:config )
  fi

  if [[ -d src/ ]] &&
    src=$(find src/ -maxdepth 2 -type f -print -quit) &&
    [[ ${src:+set} && -f "$src" ]]
  then
    xredo_all_targets+=( @build )
    xredo_build_targets+=( @build:ns1 )

    if [[ -d var/schema/ ]] &&
      sch=$(find var/schema/ -maxdepth 1 -type f -print -quit) &&
      [[ ${sch:+set} && -f "$sch" ]]
    then
      xredo_build_targets+=( @build:schema )
    fi
    unset sch
  fi

  if [[ -d test/ ]] &&
    test=$(find test/ -maxdepth 1 -type f -print -quit) &&
    [[ ${test:+set} && -f "$test" ]]
  then
    xredo_all_targets+=( @test )
  fi
  xredo_all_targets+=( @check )
  unset src test

  seed=etc/redo_default+seed.bash
  [[ -s $seed ]] || seed=$US_SKELETON_DIR/$seed

  [[ -z "${XREDO_CONFIG%/*}" ]] || mkdir -vp "${XREDO_CONFIG%/*}"

  cp "$seed" "${XREDO_CONFIG:?}" &&
  repl_all="xredo_all_targets=( ${xredo_all_targets[*]} )" &&
  repl_build="xredo_build_targets=( ${xredo_build_targets[*]} )"  &&

  ed - "${XREDO_CONFIG:?}" <<EOF
/^#xredo_all_targets=/c
$repl_all
.
/^#xredo_build_targets=/c
$repl_build
.
\$s/redo_default+seed\ /redo_default+local/
w
q
EOF
  #echo "# Generated at $(date --iso=sec), by ${0##*/} PID $$" >> "${XREDO_CONFIG:?}"

  unset seed repl_{all,build}
fi

# Configure Redo (script files)

if [[ ! -e ${XREDO_ENV:=.local/var/xredo_env.bash} ]]; then
  xredo_env_sources=(
    "env_common.bash"
    "dsl-common.bash"
  )
  xredo_scr_sources=(
    "build-select.bash"
    "build_common.bash"
    "build_schema.bash"
    "us-bbb.ns0.bash"
  )

  path=$PATH:tool/local:$US_SKELETON_DIR/tool/local

  declare -ga env_files
  for xredo_env_src in "${xredo_env_sources[@]}"; do
    env_files+=( "$(PATH=$path \builtin command -v "${xredo_env_src:?}")" )
  done

  declare -ga build_configs
  for xredo_scr in "${xredo_scr_sources[@]}"; do
    build_configs+=( "$(PATH=$path \builtin command -v "${xredo_scr:?}")" )
  done

  declare -gn \
    build_select='build_configs[0]' \
    build_common='build_configs[1]' \
    build_schema='build_configs[2]' \
    us_bbb_ns0='build_configs[3]' \
    BUILD_SELECT_SH=build_select

  build_env=(
    env_files
    build_{configs,select,common,schema}
    us_bbb_ns0
    BUILD_SELECT_SH
    usertools_namemap
    US_NS_STATE
    PACKAGE_NAMEMAP_YAML
  )

  [[ -z "${XREDO_ENV%/*}" ]] || mkdir -vp "${XREDO_ENV%/*}"
  {
    echo "# skeleton template env"
    declare -p "${local_template_env_vars[@]}" |
      sed 's/^declare --*\([xn]*\)/declare -g\1/'
    echo "# build env configuration"
    declare -p "${build_env[@]}" |
      sed 's/^declare --*\([xn]*\)/declare -g\1/'
    echo "# Local and skeleton tool/local path"
    echo "PATH+=:tool/local:\$US_SKELETON_DIR/tool/local"
    echo export PATH
    echo
    echo . \"${XREDO_CONFIG:?}\"
    printf '. "%s"\n' "${env_files[@]}"
    echo "# Generated at $(date --iso=sec), by ${0##*/} PID $$"
  } > "${XREDO_ENV:?}"

  unset path local_template_env_vars build_env
fi

if [[ $US_LOCAL_ENV != /* &&
  ${GIT_PROJECT_REPOSITORY} != "${GIT_TEMPLATE_REPOSITORY}"
]]; then
  : 'leave as is'
  >&2 declare -p GIT_PROJECT_REPOSITORY GIT_TEMPLATE_REPOSITORY US_LOCAL_ENV || :
  >&2 echo "Locally configured, not updating LOCAL_ENV"
else
  : 'localize'
  LOCAL_ENV=.local/env/default.bash
  LOCAL_CLEAN_PATH=(
    .redo
    .local/cache
    .local/build
    .local/var
    "${us_skeleton_copy[@]}"
    "${us_skeleton_symlink[@]}"
  )
  : "${XREDO_CORES:=10}"
  LOCAL_CLEAN_VAR=(
    XREDO_{CONFIG,ENV}
    LOCAL_ENV
  )
  [[ -z "${LOCAL_ENV%/*}" ]] || mkdir -vp "${LOCAL_ENV%/*}"
  {
    echo "# Extending from configure US_LOCAL_ENV"
    printf '. "${%s:=%s}"\n' US_LOCAL_ENV "${US_LOCAL_ENV:?}"
    echo 'export UC_ENV_CONFIG_PID=$$'
    echo "# Redo config"
    printf ': "${%s:=%s}"\n' XREDO_CONFIG "${XREDO_CONFIG:?}"
    printf ': "${%s:=%s}"\n' XREDO_CORES "${XREDO_CORES:?}"
    printf ': "${%s:=%s}"\n' XREDO_ENV "${XREDO_ENV:?}"
    echo "# Local and skeleton tool/local path"
    printf ': "${%s:=%s}"\n' US_SKELETON_DIR "${US_SKELETON_DIR:?}"
    echo "PATH+=:tool/local:tool/local/exec"
    echo "PATH+=:\$US_SKELETON_DIR/tool/local:\$US_SKELETON_DIR/tool/local/exec"
    echo export PATH
    echo "# Env overrides and exports"
    for _env in "${env_overrides[@]}" "${env_exports[@]}"; do
      printf 'export %s=%q\n' "${_env:?}" "${!_env-}"
    done
    echo
    echo "# Reset config"
    echo 'RESET_PATHS=( '
    printf '  %q\n' "${LOCAL_CLEAN_PATH[@]}"
    for var in "${LOCAL_CLEAN_VAR[@]}"; do : "${!var:?}"; echo "  ${_@Q}"; done
    echo ')'
    cat <<'EOM'

case "${0##*/}" in default.bash )

  drop_paths() {
    # TODO: build-in prompt or require --force or --yes
    rm -rf "${RESET_PATHS[@]:?}" &&
    echo "All resettable files dropped"
  }

  case "${1-}" in
    ( --help ) cat <<EOM_
Usage:
  default.bash --reset           Delete resettable paths
  default.bash --reconfigure     Delete paths and reconfigure

Deletes the following paths:
$(for path in "${RESET_PATHS[@]:?}"; do
    echo "  - ${path@Q}"
  done)

EOM_
;;

    ( --reconfigure ) drop_paths &&
        bash "${US_SKELETON_DIR:?}/configure+skeleton.bash" &&
        redo @config
      ;;

    ( --reset ) drop_paths ;;

    ( * ) >&2 echo "Unkown argument ${1@Q} ($0)"
      exit 1 ;;
  esac
esac

EOM
    echo "# Generated at $(date --iso=sec), by ${0##*/} PID $$"
  } >| "${LOCAL_ENV:?}"
  >&2 echo "Local env configured, see LOCAL_ENV=${LOCAL_ENV} --help"
fi

# TODO: improved matching and rules for local and global tag handling

# TODO: init other resources: license, docs, alt. gitignore setups

# Id: configure+skeleton+us                      vim:set ft=bash sw=2 sts=2 et:
