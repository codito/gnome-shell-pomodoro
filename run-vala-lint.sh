#!/bin/sh

PROJECT_PATH="`dirname "$0"`"
CONFIG_PATH="lint/vala-lint.ini"
FILES=(
    "src/*.vala"
    "tests/*.vala"
    "plugins/*/*.vala"
)

cd $PROJECT_PATH
io.elementary.vala-lint --config=$CONFIG_PATH $FILES
