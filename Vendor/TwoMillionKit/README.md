# TwoMillionKit (vendored)

Vendored from [insidegui/TwoMillionKit](https://github.com/insidegui/TwoMillionKit) so copyas can build on macOS 26 while Private Cloud Compute remains a macOS 27+ runtime feature.

This target is only compiled when `COPYAS_ENABLE_PCC` is enabled (automatic on macOS 27+ build hosts, disabled on macOS 26 CI via `COPYAS_ENABLE_PCC=0`).

Update by syncing `FMToolLanguageModel.swift` from upstream when needed.
