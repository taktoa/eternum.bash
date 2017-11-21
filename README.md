# `eternum.bash`

## Introduction

`eternum.bash` is a command line interface to the [eternum.io][] API.

[eternum.io]: https://www.eternum.io

## Dependencies

`eternum.bash` depends on:

- `curl`
- `jq`
- `gpg` version 2.0 (it needs the `gpg2` command)
- GNU `bash`
- GNU `sed`
- GNU `grep`
- GNU `coreutils`

## Usage

```
eternum: the eternum.io command line interface.

Usage:
  eternum (-h | --help)
  eternum --version
  eternum list
  eternum pin    <hash> <name>
  eternum rename <hash> <new-name>
  eternum unpin  <hash>
  eternum stats  <hash>

Options:
  -h --help    Show this screen.
  --version    Show version.
```
