#!/bin/sh

# Bump the version. If this is commented out, the next line will cause the git
# dependency to update!
sed -i '' -e "s/^version = \"\(.*\)\"/version = \"\11\"/" Cargo.toml
cargo update -p crate2
