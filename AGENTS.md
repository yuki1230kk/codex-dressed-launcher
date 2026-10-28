# Agent installation and maintenance guide

This is a source-preview community launcher, not a signed, zero-configuration installer.

## When a user asks to install

1. Read README.md and docs/MACOS.md or docs/WINDOWS.md before running anything. Work on the user's actual desktop host; a cloud container alone cannot install into their desktop.
2. Inspect OS, architecture, official client identity, Dream Skin installation and existing launch/animation services. Do not alter or terminate a running client without the user's authorization to interrupt that session.
3. Use the linked official upstream repositories for dependencies. The integration targets Dream Skin 1.5.21 script interfaces. Verify that a different version exposes compatible functions; do not silently replace protected client files or disable security controls.
4. Ask for missing theme/video choices only as needed. Theme packages must go through Dream Skin's importer; never bypass platform, archive or asset validation. See docs/THEME-SOURCES.md. Do not assume a theme downloaded for Windows supports macOS.
5. Create the user's configuration outside the repository. Fill actual engine/video paths and installed theme IDs. Do not leave placeholder IDs or overwrite an existing configuration silently.
6. Run the platform installer and verify the resulting entry. The installer itself does not fetch Dream Skin, videos or themes. Do not describe dependency discovery as successful installation.
7. Coordinate one user-initiated exit and cold start for end-to-end verification. Follow docs/TESTING.md. Preserve the single-launch invariant: animation must never launch the client; failure must never restart it.
8. Report the exact entry to use, what was tested, remaining issues, log location and uninstall instructions. A running unthemed client cannot acquire this setup's startup flags without a later cold start.

## Maintaining this repository

- Keep official client bundles, credentials, profiles, logs, personal config and media out of Git.
- Retain upstream attribution and licenses. Code licensing does not authorize third-party media redistribution.
- Run macOS adapter tests and PowerShell tests as applicable. Distinguish mocked tests from Windows GUI validation.
- Do not infer permission to publish, upload or create a release from installation or code-edit requests.
- Do not remove failure checks or add automatic client restart/fallback paths to make tests pass.
