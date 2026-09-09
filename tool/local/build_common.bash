# build_common.bash is the current home for the basic project target recipes
#
# Copyright (c) 2026 .mpe  <me@dotmpe.com>
#
# Distributed under terms of the MIT license.

:bashunit-reports-summary() {
  local -n _Reports=$1
  local summary=.local/build/bashunit/test-summary.csv

  local us_bashunit_summary_keys=(
    total passed failed skipped incomplete flaky duration_ms
  )
  local {,_}jq {,_}rs "${us_bashunit_summary_keys[@]}"

  mapfile -t us_bashunit_summary_fields <<< "$(printf '.summary.%s\n' "${us_bashunit_summary_keys[@]:?}")" &&
  mapfile -t _jq <<< "$(printf '(%s)\n' "${us_bashunit_summary_fields[@]:?}")" &&
  printf -v jq '[%s] | @tsv' "$(IFS=,; echo "${_jq[*]:?}")" &&

  _rs=0 &&
  for rs in "${reports[@]}"; do
    if [[ -e "$rs" ]]; then
      __="$(jq -r "$jq" "$rs")" &&
      read -r "${us_bashunit_summary_keys[@]}" <<< "${__:?}"
      summaries+=( "$__" )

      if (( failed > 0 )); then
        results+=( 7 )
      elif (( incomplete > 0 )); then
        results+=( 8 )
      elif (( flaky > 0 )); then
        results+=( 6 )
      elif (( skipped > 0 )); then
        results+=( 5 )
      else
        results+=( 0 )
      fi
      ((_rs+=1))
    else
      results+=( 9 )
    fi
  done
  say.v "Found $_rs module test reports, $(( ${#reports[*]} - _rs )) missing"
  :to-v printf '%s\n' "${summaries[@]}"
}

:config-warning() {
  config_seed=etc/redo_default+seed.bash
  build_config=.local/etc/redo_default.bash
  say.v "Config incomplete at ${build_config} (see seed at ${config_seed@Q})" || return
}

:uc-diag:forbidden-patterns() {
  # NOTE: keep patterns in plain text config, outside scans
  redo-ifchange etc/diag_forbidden_patterns.bash.lines &&
  :pass "$(< $_ )" &&
  \builtin . <(printf "forbidden=(\m%s\n)" "$_") &&
  [[ ${forbidden[*]:+set} ]] ||
    :failerr "No forbidden patterns configured" || return

  # Search (grep) file for certain expressions, warn about match(es)
  for x in "${forbidden[@]}"; do
    :to-v grep -HPn "^[^#:]*$x" "$script" || continue
    :failerr "Found forbidden ${x@Q}, see before lines" || return
  done

  redo-stamp <<< "${forbidden[*]}"
}

:uc-diag:shell-lint-check() {
  local lang
  lang=${xredo_ext_langmap["${script##*.}"]:-bash}
  \builtin command shellcheck --shell=$lang "$script" >&${USER_FD:?}
}

:uc-diag:shell-load-plus-lint-check() {
  ( \builtin . "$script" ) ||
    :failerr "E$? on test-loading ${script@Q}" || return
  \builtin . <(:uc-diag:shell-lint-check)
}

:uc-diag:todo-comments() {
  TODO "implement comment scan"
}

:uc-diag:unguarded-tooling-invocations() {

  # FIXME: this does not work right yet; should require \builtin command for
  # certain toolkit commands (for recognition)
  # And for source/. (eval is kept in forbidden expressions)
  # But for other may introduce \reserved or \uc_reserved or similar. And should
  # know (scan/index) those with us-pp.
  # Same for some other commands, should require \inline prefix (later).
  redo-ifchange etc/diag_core_tooling.list &&
  mapfile -t cmds < $_ &&
  [[ ${cmds[*]:+set} ]] ||
    :failerr "No cmds configured" || return

  :pass "$(IFS='|'; echo "${cmds[*]}")" &&
  :to-v grep -HPn "^[^#:]*(?<!\\\bbuiltin[ \t])(?<!\\\)\b(${_:?})\b" -- "$script" ||
    return 0
  :failerr "Found unguarded tooling invocation(s), see before lines"
}

:xredo-build-namemap-target() {

  redo-ifchange "${PACKAGE_NAMEMAP_YAML:?}" &&
  PACK_PREF=us_pack_ \
  MOD_PREF=us_mod_ \
  FWDKEY=ns0_names \
  BWDKEY=name_to_ns0 \
  usertools-namemap.sh "$PACKAGE_NAMEMAP_YAML" >| "${usertools_namemap:?}" &&
  redo-stamp < <(grep -Pv '^([\t ]*|[\t ]*\#.*)$' "${usertools_namemap:?}")
}

:xredo-build-ns1-target() {
  local src
  for src in "${redo_sources[@]:?}"; do
    src=${src#src/}
    redo_targets+=( "@index:${src:?}" )
    redo_targets+=( "pack/ns1/${src%.inc}.bash" )
  done &&
  redo-ifchange "${redo_sources[@]}" "${redo_targets[@]}"
}

:xredo-build-target() {
  redo-always &&
  if [[ ${xredo_build_targets[*]:+set} ]]; then
    redo-ifchange "${xredo_build_targets[@]:?}" &&
    redo-stamp <<< "${xredo_build_targets[@]}" || return
  else
    :config-warning
    say.v "No build targets to run (ignored)"
  fi
}

:xredo-check-recipe() {
  local diag script
  : "${XREDO_TARGET#@check:}"; IFS=: read -r script diag <<<"${_}" &&
  : "${script:?$(:unset-err script 'Input source file')}"

  redo-ifchange "$script" &&
  # TODO: act on and handle $diag setting
  case "$script" in

  ( pack/* )
      # TODO: rewrite parts so they can be used as recipe target
      #: "${diag:=@uc-diag:shell-lint-check}"
      :uc-diag:shell-load-plus-lint-check
    ;;

  ( src/* | tool/local/common* )
      :uc-diag:shell-load-plus-lint-check &&
      :uc-diag:forbidden-patterns &&
      #:uc-diag:unguarded-tooling-invocations &&
      : # :uc-diag:todo-comments
    ;;

  ( *.do | test/* | tool/* )
      :uc-diag:shell-lint-check &&
      :uc-diag:forbidden-patterns &&
      : #:uc-diag:todo-comments
    ;;

  ( *.yaml | *.md )
      # :uc-diag:forbidden-patterns &&
      # :uc-diag:todo-comments
    ;;

  ( * ) :failerr "There is no check action for script ${script@Q}"
  esac
}

:xredo-check-target() {
  redo-always
  redo-ifchange "${xredo_build_targets[@]}" || return

  # Makes no sense to test after incomplete build (ie. running redo -k)
  # NB: redo-ifdone cannot work on redo-always targets, of course
  #if [[ ! ${REDO_ALL:+set} && ${xredo_build_targets[*]:+set} ]]; then
  #  redo-ifdone "${xredo_build_targets[@]}" ||
  #    :failerr "Build incomplete, cancelling @check" || return
  #fi

  local files targets
  # FIXME: autoconfigure glob entirely
  files=(
    # {,.}*.yaml
    *.md
    doc/*.md
    default.do
    # src/*/*.inc
    tool/local/*.*
  )
  if [[ -d test ]]; then
    files+=( test/*.* )
  fi
  if [[ -d tool/local/exec ]]; then
    files+=( tool/local/exec/*.* )
  fi
  if [[ -d tool/local/part ]]; then
    files+=( tool/local/part/*.* )
  fi
  for file in "${files[@]}"; do
    # TODO: make some grouping(s) of diag/src sets, not all should always need
    # to be on. CI would have the most complete set, then the (full) test
    # branch, but other envs/branches may get fewer diag (or none; ie "dev")
    # @uc-diag:regression-grep
    targets+=( "@check:$file" )
  done
  redo-ifchange "${targets[@]}" &&
  if [[ ! ${xredo_build_targets[*]:+set} ]]; then
    say.err "No build targets set (ignored)"
    # TODO "guided setup? copy seed/example files for CI build?"
  fi
}

:xredo-config-target() {
  local redo_sources tools
  redo-ifchange "${build_select:?}" || return
  if [[ -d src/ ]]; then
    redo_sources=( src/*/*.inc )
    :dump-pretty-globals redo_sources >| ./.local/var/redo_sources.bash &&
    redo-stamp <<< "${redo_sources[@]}" || return
  fi
  # TODO: move and work out tools path/script/etc scans more fully elsewhere
  # do in configure.bash perhaps instead of here same as other include paths
  if [[ -d tool/local/exec ]]; then
    tools=( tool/local/exec/*.* )
  fi
  for tool in "${tools[@]}"; do
    [[ -x "$tool" ]] || continue
    scr=${tool##*/}
    if [[ -h $scr && ! -e $scr ]]; then rm "$scr"; fi
    if [[ ! -h $scr ]]; then
      if [[ -e $scr ]]; then
        say.err "config: Local tool path exists: ${scr@Q} (ignored)"
        continue
      fi
      :to-v ln -sv "$tool" ${tool##*/} || return
    fi
  done
}

:xredo-index-recipe() {
  src=src/${XREDO_TARGET#@index:}

  redo-ifchange "$src" "${us_bbb_ns0:?}" &&
  \builtin . "${us_bbb_ns0:?}" >&${USER_FD:?} &&
  us_ppp_index=1 .run "$src" .match-line >/dev/null ||
    :failerr "Indexing ${src@Q}"
}

:xredo-pack-recipe() {
  : "${XREDO_TARGET#pack/ns[0-9]/}"
  src=src/${_%.bash}.inc

  redo-ifchange "$src" "${us_bbb_ns0:?}" &&
  mkdir -p "${XREDO_TARGET%/*}" &&

  \builtin . "${us_bbb_ns0:?}" >&${USER_FD:?} &&
  .run "$src" .match-line > "$BUILD_TARGET_TMP" ||
    :failerr "Building ns1 for ${src@Q}"
}

:xredo-pack-target() {
  redo-always
  TODO package
}

:xredo-test-recipe() {
  local modid module_test covopts silent bashunit_argv

  modid=${XREDO_TARGET#@test:}
  if ! (shopt -s failglob; : test/"${modid:?}"_test.* ) 2>/dev/null; then
    say.err "No tests for $modid"
    # TODO: require tests later
    return
  fi

  #:cache-load ./etc/bash/us_bbb_specials.bash &&
  #export -f "${us_bbb_specials[@]:?}" &&
  #export US_BBB_ENV=1 ||
  #  say.err "Failed at loading specials" || return

  # FIXME: enable coverage later as tests are started to be written
  covopts=(
    --coverage-paths 'src,pack'
    --coverage --coverage-min 80
  )
  silent=(
    #--failures-only
    #--simple            # Or export BASHUNIT_SIMPLE_OUTPUT=true
    --no-output
  )
  bashunit_argv=(
    --env test/_test_bootstrap.sh
    --fail-on-flaky
    "${silent[@]}"
  )
  module_tests=( test/"${modid:?}"_test.* )

  #shellcheck disable=2295  # expansion is unquoted?
  redo-ifchange @test:config "${module_tests[@]}" &&
  testid=${modid//[^A-Za-z0-9_]/_} &&
  #testid=$(sha256sum < <(printf '%s\n' "${tests[@]}")) &&
  # :to-v declare -p testid &&
  export BASHUNIT_REPORT_JSON=.local/build/bashunit/test-report-$testid.json &&
  #export BASHUNIT_REPORT_JUNIT=.local/build/bashunit/test-report-$testid.junit.xml &&
  #export BASHUNIT_REPORT_TAP=.local/build/bashunit/test-report-$testid.tap &&
  mkdir -vp ".local/build/bashunit" &&
  : $'[\t ]' &&
  testid=${testid%%$_*} &&
  mkdir -p .local/build &&
  \builtin command bashunit "${bashunit_argv[@]}" \
      "${module_tests[@]}" >&${USER_FD:?}
}

:xredo-test-target() {
  redo-always
  redo-ifchange "${xredo_build_targets[@]}" || return

  # Makes no sense to test after incomplete build (ie. running redo -k)
  #if [[ ! ${REDO_ALL:+set} && ${xredo_build_targets[*]:+set} ]]; then
  #  redo-ifdone "${xredo_build_targets[@]}" ||
  #    :failerr "Build incomplete, cancelling @test" || return
  #fi

  # TODO: validate actual data with schema too
  if [[ ! -d pack/ns1 ]]; then
    :failerr "Nothing to test (ns1 pack missing)" || return
  fi
  say.debug "Starting pre-test checks"
  local targets
  for x in pack/ns1/usrtools_usr{conf,scr}/*.bash; do
    targets+=( @check:"$x" )
  done
  redo-ifchange "${targets[@]}" || return
  unset targets
  local reports results testfail rs
  say.info "All current packs checked OK, starting tests..."
  for x in pack/ns1/usrtools_usr{conf,scr}/*.bash; do

    # FIXME: get ns1_modulename
    : "${x##pack/ns1/}"
    : "${_%.bash}"
    : "${_/usrconf\/}"
    __="${_/usrscr\/}"
    targets+=( @test:"$__" )
    reports+=( .local/build/bashunit/test-report-"${__}".json )
  done
  rm -f "${results[@]}" &&
  redo-ifchange "${targets[@]}" || testfail=$?

  # Serialize test results
  :bashunit-reports-summary reports || :

  return ${testfail-}
}

# Id: build_common                               vim:set ft=bash sw=2 sts=2 et:
