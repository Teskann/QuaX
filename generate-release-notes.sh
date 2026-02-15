#!/bin/bash

python generate_changelog_and_release_notes.py "$1" "$(git log "$(git describe --tags --abbrev=0)"..HEAD --reverse --pretty=format:"%H%n%aN%n%s%n")"
