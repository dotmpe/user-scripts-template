#!/bin/bash
#
# build-select.bash - Configurable main project build file for default.do
#
# Copyright 2026 .mpe  <me@dotmpe.com>
#
# Distributed under terms of the MIT license.
#

[[ ${REDO_RUNID+set} ]] || {
  :failerr "build-select is a redo/recipe internal only script" || return
} || exit

XREDO_TARGET="${REDO_PWD:+$REDO_PWD/}${REDO_TARGET:?}"
# XRedo/Base: Actual initial (path, name or id) spec for target
XREDO_BASE=${XREDO_TARGET%%:*}
XREDO_NODE=${XREDO_TARGET%:*}

: 'Config must be ready before any other target, except @*:config'

case "${XREDO_TARGET}" in @config | @*:config ) ;; ( * )

  : NOTE 'paralellized builds will trip on redo-ifdone, even with the proper
          input sequence. Split the build into *sequential* invocations'

  if ! >&2 redo-ifdone @config; then
      say.err "Must run @config first (to build ${XREDO_TARGET@Q})"
      exit 1
  fi

esac

\builtin . "${build_common:?}" &&

case "${XREDO_TARGET}" in

( @build )
: about 'Perform all build targets, stamp with recipe, and taint when @build:config changes'
    :xredo-build-target &&
    redo-stamp <<< "$(:funbody $_)" &&
    redo-ifchange @build:config
  ;;

( @build:config )
: about 'Stamp build target list and recipe function names (build select/common)'
    redo-ifchange @build:scripts:config &&
    redo-stamp < <(grep -Po '^\(\ [^\)]+\ \)$' "${build_select:?}") &&
    redo-stamp < <(grep -Po '^:xredo-[A-Za-z0-9.:+-]+(?=\(\))' "${build_common:?}")
  ;;

( @build:name:config )
    :xredo-build-namemap-target &&
    redo-stamp <<< "$(:funbody $_)" &&
    redo-ifchange @build:config
  ;;

( @build:ns1 )
: about 'Build the intial distribution name space; stamp recipe; taint on @build:config change'
    :xredo-build-ns1-target &&
    redo-stamp <<< "$(:funbody $_)" &&
    redo-ifchange @build:config
  ;;

( @build:schema_:config )
: about 'Stamp schema build recipe function names'
    redo-ifchange @build:config "${build_schema:?}" &&
    redo-stamp < <(grep -Po '^:xredo-[A-Za-z0-9.:+-]+(?=\(\))' "${build_schema:?}")
  ;;

( @build:schema:* )
: about 'Test compile LinkML schema (all generators)'
    \builtin . "${build_schema:?}" &&
    :xredo-build-schema-recipe &&
    redo-stamp <<< "$(:funbody $_)"
  ;;

( @build:schema )
: about 'Validate (test compile) every schema'
    redo-ifchange @build:schema_:config &&
    \builtin . "${build_schema:?}" &&
    :xredo-build-schema-target &&
    redo-stamp <<< "$(:funbody $_)"
  ;;

( @build:scripts:config )
: about 'Stamp build script name sequence'
    redo-ifchange "${build_configs[@]:?}" &&
    redo-stamp <<<"${build_configs[*]:?}"
  ;;

( @check )
: about 'Run all source and project checks; stamp with recipe script'
    :xredo-check-target &&
    redo-stamp <<< "$(:funbody $_)" &&
    redo-ifchange @build:config
  ;;

( @check:* )
: about 'Run parameterized recipe; stamp with script body (typical)'
    :xredo-check-recipe &&
    redo-stamp <<< "$(:funbody $_)" &&
    redo-ifchange @build:config
  ;;

( @config )
: about 'Run target recipe; stamp with script body (typical)'
    :xredo-config-target &&
    redo-stamp <<< "$(:funbody $_)" &&
    redo-ifchange @build:config
  ;;

( @index:* )
    :xredo-index-recipe &&
    redo-stamp <<< "$(:funbody $_)" &&
    redo-ifchange @build:config
  ;;

( @pack )
    :xredo-pack-target &&
    redo-stamp <<< "$(:funbody $_)" &&
    redo-ifchange @build:config
  ;;

( @test )
    :xredo-test-target &&
    redo-stamp <<< "$(:funbody $_)" &&
    redo-ifchange @build:config
  ;;

( @test:config )
: about 'Stamp with all bootstrap script lines (static)'
    redo-ifchange test/_test_bootstrap.sh &&
    redo-stamp < <(grep -Pv '^([\t ]*|[\t ]*\#.*)$' test/_test_bootstrap.sh)
  ;;

( @test:* )
    :xredo-test-recipe &&
    redo-stamp <<< "$(:funbody $_)" &&
    redo-ifchange @build:config
  ;;


( pack/*/* )
    :xredo-pack-recipe &&
    redo-stamp <<< "$(:funbody $_)" &&
    redo-ifchange @build:config
  ;;


( * )
    return ${_E_next:-196}

esac

# Id: build-select                               vim:set ft=bash sw=2 sts=2 et:
