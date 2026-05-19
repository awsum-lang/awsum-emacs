# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

`awsum-emacs` is versioned 1:1 with the `awsum` compiler — the package's `A.B.C` is exactly the `awsum` `A.B.C` it targets. Every `awsum` release ships a matching package release, the package is never released ahead of the compiler, and only the latest `awsum` release is supported.

Until `awsum 1.0.0`, the project does not follow SemVer — every release increments only the patch (`0.0.1 → 0.0.2 …`), and any release may break. The 1:1 lockstep above is the contract that does hold: within a single `0.0.x`, the package and the `awsum` it ships against are mutually compatible.

## [Unreleased]

## [0.0.4] - 2026-05-19

### Added

- Initial release. Thin LSP client to `awsum lsp --stdio` (subcommand of the `awsum` compiler binary) wired through the built-in [`eglot`](https://www.gnu.org/software/emacs/manual/html_mono/eglot.html). Every editor feature is computed inside the compiler and pushed over LSP:
  - **Syntax highlighting** via the built-in `treesit` runtime. The tree-sitter parser is installed automatically on first `.aww` open through `treesit-install-language-grammar` (which clones [`awsum-lang/tree-sitter-awsum`](https://github.com/awsum-lang/tree-sitter-awsum) at the pinned tag and compiles via the system C compiler). The font-lock rules are an elisp port of `tree-sitter-awsum/queries/highlights.scm` written as `treesit-font-lock-rules`. They include a fix that the upstream `.scm` lacks — bare type references like `Int32` in `unused : Int32` and the leaves of `A -> B`, `A | B` now highlight correctly.
  - **Format on save** via `textDocument/formatting` — same algorithm as `awsum format`. Bound to `eglot-format-buffer` (opt-in via `before-save-hook` snippet in README).
  - **Inline diagnostics** via `textDocument/publishDiagnostics` — routed to the built-in `flymake` (debounced 500 ms server-side; `error` / `warning` severity honoured).
  - **Quick fixes** via `textDocument/codeAction` — compiler-supplied fixes only; surfaced via `eglot-code-actions`.
  - **Document symbols** via `textDocument/documentSymbol` — drives `imenu` and any imenu-consuming UI.
  - **Workspace symbol search** via `workspace/symbol` — accessible through `xref-find-apropos`.
- Declarative lockstep version check: the package passes `initializationOptions: { expectedAwsumVersion, preferButtonsOverLinks: true }` and the server warns on mismatch via `window/showMessageRequest`. Emacs maps that to `completing-read`. The expected version is the single source of truth from `(defconst awsum-version ...)` in `awsum.el`.
- Emacs 29.1+ minimum: the package uses only built-in APIs — `eglot` (no `lsp-mode` dependency), `treesit` (no `tree-sitter-langs` dependency), `package-vc-install` / `use-package :vc` for installation (no `straight.el` / `quelpa` dependency).
- `just install-local` / `just uninstall-local` for development against a checkout (symlinks the working copy into `~/.emacs.d/elpa/awsum/` via `package-vc-install-from-checkout`, so `emacs file.aww` auto-loads without editing `init.el`).
