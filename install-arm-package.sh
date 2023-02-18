#!/bin/bash

set -e -u -o pipefail

DEFAULT_ARM_REPO_URL="http://mirror.archlinuxarm.org/aarch64/core"

stderr() { 
  echo "$@" >&2 
}

debug() {
  stderr "--- $@"
}

extract_href() {
  sed -n '/<a / s/^.*<a [^>]*href="\([^\"]*\)".*$/\1/p'
}

fetch() {
  curl -L -s "$@"
}

fetch_file() {
  local FILEPATH=$1
  shift
  if [[ -e "$FILEPATH" ]]; then
    curl -L -z "$FILEPATH" -o "$FILEPATH" "$@"
  else
    curl -L -o "$FILEPATH" "$@"
  fi
}

uncompress() {
  local FILEPATH=$1 DEST=$2
  
  case "$FILEPATH" in
    *.gz) 
      tar xzf "$FILEPATH" -C "$DEST";;
    *.xz) 
      xz -dc "$FILEPATH" | tar x -C "$DEST";;
    *.zst)
      zstd -dc "$FILEPATH" | tar x -C "$DEST";;
    *)
      debug "Error: unknown package format: $FILEPATH"
      return 1;;
  esac
}  

###

fetch_packages_list() {
  local REPO=$1 
  
  debug "fetch packages list: $REPO/"
  fetch "$REPO/" | extract_href | awk -F"/" '{print $NF}' | sort -rn ||
    { debug "Error: cannot fetch packages list: $REPO"; return 1; }
}

install_packages() {
  local PACKAGES=$1 DEST=$2 LIST=$3 DOWNLOAD_DIR=$4
  debug "pacman package and dependencies: $PACKAGES"
  
  for PACKAGE in $PACKAGES; do
    local FILE=$(echo "$LIST" | grep -m1 "^$PACKAGE-[[:digit:]].*\(\.gz\|\.xz\|\.zst\)$")
    test "$FILE" || { debug "Error: cannot find package: $PACKAGE"; return 1; }
    local FILEPATH="$DOWNLOAD_DIR/$FILE"
    
    debug "download package: $REPO/$FILE"
    fetch_file "$FILEPATH" "$REPO/$FILE"
    debug "uncompress package: $FILEPATH"
    uncompress "$FILEPATH" "$DEST"
  done
}

show_usage() {
  stderr "Usage: $(basename "$0") [-q] [-a i686|x86_64|arm] [-r REPO_URL] [-d DOWNLOAD_DIR] DESTDIR"
}

main() {
  test $# -eq 0 && set -- "-h"

  local PACKAGES=
  local REPO_URL=
  local DOWNLOAD_DIR=
  local PRESERVE_DOWNLOAD_DIR=
  
  while getopts "r:d:h:p:" ARG; do
    case "$ARG" in
	  r) REPO_URL=$OPTARG;;
	  p) PACKAGES=$OPTARG;;
      d) DOWNLOAD_DIR=$OPTARG
         PRESERVE_DOWNLOAD_DIR=true;;
      *) show_usage; return 1;;
    esac
  done
  
  shift $(($OPTIND-1))

  test $# -eq 1 || { show_usage; return 1; }

  [[ -z "$PACKAGES" ]] && { show_usage; return 1; }
  
  [[ -z "$REPO_URL" ]] && REPO_URL=$DEFAULT_ARM_REPO_URL
  
  local DEST=$1
  local REPO=$REPO_URL

  [[ -z "$DOWNLOAD_DIR" ]] && DOWNLOAD_DIR=$(mktemp -d)
  mkdir -p "$DOWNLOAD_DIR"
  [[ -z "$PRESERVE_DOWNLOAD_DIR" ]] && trap "rm -rf '$DOWNLOAD_DIR'" KILL TERM EXIT

  debug "destination directory: $DEST"
  debug "repository: $REPO"
  debug "temporary directory: $DOWNLOAD_DIR"
  
  # install packages
  mkdir -p "$DEST"
  
  local LIST=$(fetch_packages_list $REPO)
  install_packages "${PACKAGES[*]}" "$DEST" "$LIST" "$DOWNLOAD_DIR"

  [[ -z "$PRESERVE_DOWNLOAD_DIR" ]] && rm -rf "$DOWNLOAD_DIR"
  debug "Done!"
}

main "$@"


