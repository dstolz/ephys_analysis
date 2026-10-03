# Changelog

Notable changes to this repository. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and version numbers
follow [Semantic Versioning](https://semver.org/). The current number is in
[`VERSION`](VERSION); [README.md](README.md#versions-license-and-citation)
says how to cut a release.

## [Unreleased]

### Added

- `LICENSE` (MIT), `THIRD_PARTY_NOTICES.md`, `CITATION.cff`, this changelog
  and a `VERSION` file that `ephysVersion` reads; `ephysVersion` also reports
  `git describe` (`Describe`).
- `run_all_tests` runs every suite through `matlab.unittest`: JUnit XML
  (`JUnit=`), HTML or Cobertura coverage (`Coverage=` / `CoverageXML=`),
  selection by name or tag. Function-style suites run as `LegacySuiteTest`,
  each failed check reported on its own; `findTestSuites` lists the suites.
- `AppPrefs` and `AppPrefsFixture`: the apps keep their preferences through
  one store, which tests and screenshot runs point at a temporary file.
- Test suites `test_AppPrefs` and `test_RepositoryMetadata`.

### Changed

- The apps and the screenshot tools no longer call `getpref` / `setpref`
  directly. The test suites no longer back up, clear and restore your
  preferences; they never touch them.
- `test_BinaryReader` is a `matlab.unittest.TestCase` class (the pattern for
  new suites), with the same checks.
- `.gitignore` covers MATLAB backups and autosaves, test-runner output,
  `.claude/worktrees` and operating-system files.

## [0.1.0] - untagged

The code on `main` up to commit `75fa4e2` (2026-10-02), before releases were
tagged. Its history is in git and in the Done list of
[ephys_analysis-TODO.md](ephys_analysis-TODO.md).
