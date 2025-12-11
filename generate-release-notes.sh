#!/bin/bash

function impl() {
  printf "## QuaX %s 🐦\n\n" "$1"
  echo "What's new in QuaX $1:"

  git log "$(git describe --tags --abbrev=0)"..HEAD --reverse --pretty=format:"  - %s (by @%aN) <sup>[[view modified code]](https://github.com/teskann/quax/commit/%H)</sup>"

  printf "\n\n"
  echo "> [!TIP]"
  echo "> If you don't know your device's architecture, download [\`quax-$1.apk\`](https://github.com/Teskann/QuaX/releases/download/$1/quax-$1.apk)"
  printf "\n\nThank you all for your support ! ❤️\n"
}

impl "$1" > changelog.md