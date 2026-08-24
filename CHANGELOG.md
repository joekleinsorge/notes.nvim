# Changelog

All notable changes to this project are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-08-23

### Added

- Configurable vault path, front matter, notifications, note extensions, hidden-file handling, and Telescope options.
- Commands for creating, finding, searching, and reopening the most recently modified note.
- Nested-note creation and command-line path completion.
- `:checkhealth notes` diagnostics.
- Headless Neovim test suite, lint and formatting configuration, and GitHub Actions CI.

### Changed

- Note creation now distinguishes prompt cancellation from the daily-note fallback.
- Recent-note selection defaults to Markdown files and ignores hidden paths and symbolic links.
- YAML front matter uses safe JSON-compatible string encoding.

### Security

- Note paths are constrained to the configured vault and reject traversal, absolute paths, control characters, and symbolic-link escapes.
- Filesystem, editor, callback, and optional-dependency failures are reported without unhandled runtime errors.

[1.0.0]: https://github.com/JoeKleinsorge/notes.nvim/releases/tag/v1.0.0
