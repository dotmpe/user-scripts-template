#!/bin/bash

# Mappings for us-pp, us-fmt-inc etc. ns0 env to run indexing & packing

# TODO: build this from derived data later, see us-bbb.group.bash
..Cache.load-file() { .load-file "$@"; }
..Cache.load-maps() { .load-maps "$@"; }
..String.join-array() { .join-array "$@"; }
..Namespace.map-to-ns1() { .map-to-ns1 "$@"; }
..Operating-System.path-append() { .path-append "$@"; }
..Shell.dump-globals() { .dump-globals "$@"; }

. "pack_common.bash"

. src/usrtools_usrconf/uc_cache.inc
._hooks:global
._hooks:load

. src/usrtools_usrscr/us_pp.inc
._hooks:global
._hooks:load

. src/usrtools_usrscr/us_os.inc
. src/usrtools_usrscr/us_str.inc
. src/usrtools_usrscr/us_ns.inc
._hooks:global
._hooks:load
. src/usrtools_usrscr/us_sh.inc
. src/usrtools_usrscr/us_fmt_inc.inc
