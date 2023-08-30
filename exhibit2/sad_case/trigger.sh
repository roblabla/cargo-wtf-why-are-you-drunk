#!/bin/sh

# Bump the version.
sed -i '' -e "s/^version = \"\(.*\)\"/version = \"\11\"/" Cargo.toml
# Cargo update
cargo update -p rootcrate
