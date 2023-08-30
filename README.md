# Cargo Update -p Considered Harmful

Cargo's handling of `cargo update -p <cratename>` is **extremely** inconsistent,
where its exact behavior is dependant on the name of the various crates, and
their current state compared to the lockfile.

In this repository, you'll find two exhibits showing inconsistencies in the
behavior of `cargo update -p`. In each exhibit will be two cases: The "happy
case" and the "sad case", each containing a `trigger.sh` that runs the
appropriate `cargo update` command to trigger the inconsistency. The expectation
here is that both cases should result in either the same result, or only trivial
changes (like local version changing) - but the dependencies should never be
updated.

## Exhibit one: Cargo does extra work if the package did not change version

Cargo seems to handle git dependencies differently depending on whether it's got
"work" to do on local crates or not. In particular, in my local monorepo, if I
bump the version of a local crate in Cargo.toml, then `cargo update -p <crate>`
will update the local lockfile to bump the versions of `crate` and nothing more.

However, if I *don't* bump the version and run the same `cargo update -p <crate>`
command, cargo will update the git dependencies.

### Reproducer

Found in the `exhibit1` directory. In this exhibit, we have a fairly simple
workspace involving two local crates, and one git dependency:

1. crate2, a binary crate, which depends on crate1
1. crate1, a library crate, which depends on a git version of rustdns.

Crucially, the lockfile pins a previous commit of the rustdns branch crate1
depends on.

Our goal here is to have a script we can run that _may_ bump the version (but
does not necessarily), and runs `cargo update -p crate2` to have the new version
in the Cargo.lock.

### Expectation

When `cargo update -p crate2` is run, it will only update things that are
_necessary_  to update crate2. If we bump the version in workspace.version, only
crate1 and crate2 should change. Crucially, the `rustdns` dependency should only
be updated if we change its definition in the workspace Cargo.toml.

### Reality: Happy Case

If we bump the version, then run `cargo update -p crate2`, cargo will have the
following output:

```bash
$ cargo update -p crate2
Updating crate1 v2.29.8 (/Users/roblabla/Documents/foss/minimal-reproducer-wtf-update/exhibit1/happy_case/crate1) -> v2.29.81
Updating crate2 v2.29.8 (/Users/roblabla/Documents/foss/minimal-reproducer-wtf-update/exhibit1/happy_case/crate2) -> v2.29.81
```

As noted, only our local crates were updated. This case matches our
expectations.

### Reality: Sad Case

If we *don't* bump the version, and run `cargo update -p crate2`, instead of not
doing anything, `cargo` will update the git dependency for no reason:

```bash
$ cargo update -p crate2
Updating git repository `https://github.com/JustRustThings/rustdns`
Updating crates.io index
Updating idna v0.3.0 -> v0.4.0
Updating rustdns v0.4.0 (https://github.com/JustRustThings/rustdns?branch=stuff-0.4.0#46ad9f03) -> #27077b0d
```

## Exhibit two: Cargo update has different behavior depending on local crate names

The name of your local crates in a workspace seems to change how cargo behaves
when running `cargo update -p <localcrate>`. In some cases (which differ only
with crate names), running `cargo update -p <localcrate>` after bumping the
version will also cause git dependencies to be updated, while in other cases it
won't...

### Reproducer

Found in the `exhibit2` directory. In this exhibit, we have a fairly simple
workspace involving two local crates, and one git dependency:

1. A library crate, which depends on a git version of rustdns.
1. A binary crate, which depends on the library crate

In this case, the only difference between the happy and sad case is the name of
the two local crates: In the happy case, the library is called crate2 while
the binary is called crate1. In the sad case, the library is called subcrate
while the binary is called rootcrate (and live in the corresponding folders).

Crucially, the lockfile pins a previous commit of the rustdns branch crate1
depends on.

Our goal here is to have a script we can run that _may_ bump the version (but
does not necessarily), and runs `cargo update -p crate2` to have the new version
in the Cargo.lock.

### Reality: Happy Case

Same as previous happy case.

### Reality: Sad Case

After bumping the version, `cargo update -p rootcrate` will update *both* the
local crates **and** rustdns to the latest git commit.

```bash
$ ./trigger.sh
Updating git repository `https://github.com/JustRustThings/rustdns`
Updating crates.io index
Updating idna v0.3.0 -> v0.4.0
Updating rootcrate v2.29.8 (/Users/roblabla/Documents/foss/minimal-reproducer-wtf-update/exhibit2/sad_case/rootcrate) -> v2.29.81
Updating rustdns v0.4.0 (https://github.com/JustRustThings/rustdns?branch=stuff-0.4.0#46ad9f03) -> #27077b0d
Updating subcrate v2.29.8 (/Users/roblabla/Documents/foss/minimal-reproducer-wtf-update/exhibit2/sad_case/subcrate) -> v2.29.81
```

The only difference with the happy case here is the name of the crates! Crate
names seem to have an impact in whether or not cargo updates the git deps???

# Workarounds

We know that `cargo update -w` is a safer command, that (at least to the best
of my knowledge) will only ever update local crates if necessary, and won't
randomly start updating git dependencies.
