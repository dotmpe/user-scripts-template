This is a skeleton file tree for a User-Script project. For the current features / status refer to the `configure+skeleton.bash` script source and its references.

## Getting Started

```bash
git clone "git@github.com:user-tools/user-scripts-template" --branch dev "/src/local/user-scripts-template+dev"
```

Start the configure script command from the project to configure, and where to copy/symlink files into.

For latest dev:

```bash
curl 'https://raw.githubusercontent.com/dotmpe/user-scripts-template/dev/configure+skeleton.bash' | bash
```

There is just the dev version currently. The `LOCAL_ENV` can be fixed after configuration, to take over local tasks. By default, or if `LOCAL_ENV` is not set to an absolute path, a ``default.bash`` is regenerated for use as `LOCAL_ENV` that also has a builtin command interface. This can be used to completely reset and/or re-configure the local project from template again, losing all build, variable and cache data:

```bash
: "${LOCAL_ENV:=".local/env/default.bash"}"
bash $LOCAL_ENV --reconfigure  # Delete resettable paths and reconfigure
bash $LOCAL_ENV --reset        # Delete resettable paths
bash $LOCAL_ENV --help         # Show help and list resettable paths
```

The local configuration in `.local/etc`, other user data, Git etc. are all left alone, except for the redo build database.

If you want to keep a local copy of the configure script: the `+skeleton` tag keeps the copy up-to-date.
It's steps are (to be) to make a clone of this template and use that as skeleton, but cloning is currently part of CI workflows only.

See the 'Features' sections for details. The normal manual setup steps would be:

```bash
: "${US_SKELETON_DIR:="/src/local/user-scripts-template+dev"}"
cp "$US_SKELETON_DIR"/configure+skeleton.bash ./configure.bash
chmod +x ./configure.bash
./configure.bash
```

The copy is not required, but it is good to be explicit about the version.
It can also be kept only at the release branch, or copied only for distribution packaging.

For dev, it is simpler to call the configure script directly:
```bash
: "${US_SKELETON_DIR:="/src/local/user-scripts-template+dev"}"
bash "$US_SKELETON_DIR"/configure+skeleton.bash
```

And after that, use the builtin commands in generated default `LOCAL_ENV` as described above.

## Features

- Copies or symlinks boilerplate files and scripts.
- It has etc/, doc/, and dotfiles, for linting project files, for a Github workflow, and LLM documents.
- It does **not** update *anything* currently, other than 1. `configure.bash` and 2. fix broken symlinks.

The main purpose (currently) is to preconfigure the **build**, so that a local redo setup can then take over project targets and life cycle;

- this does not pre-preprocess anything yet (tbd)
- also to-be done are tagged files and templates, and predefined heuristics to handle them.

  - Ie. "+template" is associated with different methods/formats/engines,
    and used to (re)generate and update local files, or just to build initial
    versions.
  - Other stand-ins for missing local files are literal, tag "+boilerplate".
  - The "+skeleton" tag scenario accesses the template at a local but separate
    work tree, where content actually lives.

Applying configuration depends on data, schema and policy further to be documented. The above is a work in progress.
