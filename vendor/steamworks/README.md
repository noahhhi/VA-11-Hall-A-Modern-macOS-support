# Steamworks redistributable

`redistributable_bin/osx/libsteam_api.dylib` is Valve's official macOS
Steamworks redistributable runtime. It contains both `arm64` and `x86_64` and
is shipped in the PKG and ZIP so installation does not depend on Steam's
internal application layout.

When updating it, use the current file from Valve's Steamworks SDK at
`sdk/redistributable_bin/osx/libsteam_api.dylib`, then run
`packaging/build-pkg.sh`. The build and install scripts reject a library that
lacks either architecture or any Steamworks entry point required by the
runner.

Current SHA-256:
`0ec33ac86de078685599d62f6d675c72e1ccfc5f8a121ef57330135c7843fc1c`.

Steamworks documentation:
<https://partner.steamgames.com/doc/sdk/api>
