# Awsum for Emacs

Emacs support for the [Awsum](https://awsum-lang.org) programming language (`.aww` files).

## Features

- Syntax highlighting (Tree-sitter)
- Code formatting (`awsum format`)
- Inline diagnostics (errors + warnings)
- Quick fixes (code actions)
- Document symbols (Imenu)
- Workspace symbol search

All of the above are powered by the `awsum` compiler's bundled language server — there is no separate `awsum-lsp` to install. As long as the `awsum` binary is on your `PATH`, the package wires Emacs's built-in [`eglot`](https://www.gnu.org/software/emacs/manual/html_mono/eglot.html) to it.

## Requirements

- **Emacs 29.1+** (uses the built-in `eglot` LSP client and the built-in `treesit` Tree-sitter runtime).
- The `awsum` compiler on your `PATH` — see [awsum-lang/awsum](https://github.com/awsum-lang/awsum).
- A C compiler + internet, to install the Tree-sitter parser on first use:
  - **macOS**: `xcode-select --install` (Xcode Command Line Tools).
  - **Linux**: `build-essential` (Debian/Ubuntu) / `base-devel` (Arch) / equivalent.
  - **Windows**: run from a "Developer Command Prompt for VS" after installing [Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/) so MSVC `cl.exe` + `link.exe` are on `PATH`. MinGW `gcc` also works if available.

  Emacs uses [`treesit-install-language-grammar`](https://www.gnu.org/software/emacs/manual/html_node/elisp/Language-Grammar.html) to clone [`tree-sitter-awsum`](https://github.com/awsum-lang/tree-sitter-awsum) and compile it on the first `.aww` open (~1 second, cached afterward in `~/.emacs.d/tree-sitter/`).

## Install

The snippets below pin to **`v0.0.4`**. Replace with the version of `awsum` you have installed — package and compiler must match (see [Versioning](#versioning)).

### Option 1: `package-vc-install` (built-in, no extra dependencies)

Emacs 29.1+ ships [`package-vc-install`](https://www.gnu.org/software/emacs/manual/html_node/emacs/Fetching-Package-Sources.html) as part of `package.el`. Run once:

```elisp
M-x package-vc-install RET https://github.com/awsum-lang/awsum-emacs RET v0.0.4 RET
```

Or as elisp in `init.el`:

```elisp
(unless (package-installed-p 'awsum)
  (package-vc-install
   '(awsum :url "https://github.com/awsum-lang/awsum-emacs"
           :rev "v0.0.4")))
```

To update later: `M-x package-vc-checkout RET awsum RET v0.0.4.1 RET` (or whatever new tag matches your `awsum`).

To uninstall: `M-x package-delete RET awsum RET`.

### Option 2: `use-package :vc` (built-in `use-package` in Emacs 30+)

```elisp
(use-package awsum
  :vc (:url "https://github.com/awsum-lang/awsum-emacs"
       :rev "v0.0.4"))
```

`use-package` is bundled with Emacs 29.1+; the `:vc` keyword was added in Emacs 30.

### Option 3: Manual via `just install-local`

For local development against a git checkout:

```sh
git clone --branch v0.0.4 https://github.com/awsum-lang/awsum-emacs ~/src/awsum-emacs
cd ~/src/awsum-emacs && just install-local
```

`just install-local` symlinks the checkout into `~/.emacs.d/elpa/awsum/` and registers it with `package.el`, so subsequent `emacs file.aww` invocations auto-load the package without editing `init.el`. To uninstall: `just uninstall-local`.

## Usage

Syntax highlighting and Eglot-powered diagnostics activate automatically on `.aww` files. Other LSP features are invoked the standard Emacs way.

### Formatting

One-shot, from inside Emacs:

```
M-x eglot-format-buffer
```

Bind a keymap (in `init.el`):

```elisp
(define-key awsum-ts-mode-map (kbd "C-c C-f") #'eglot-format-buffer)
```

Format on save:

```elisp
(add-hook 'awsum-ts-mode-hook
          (lambda ()
            (add-hook 'before-save-hook #'eglot-format-buffer nil t)))
```

The trailing `nil t` makes the inner hook **buffer-local** — `eglot-format-buffer` fires only for `.aww` buffers, never for other files.

### Diagnostics

Eglot routes diagnostics to Emacs's built-in [`flymake`](https://www.gnu.org/software/emacs/manual/html_mono/flymake.html). Default bindings:

| Action                                       | Default keymap        | Ex-command                                |
| -------------------------------------------- | --------------------- | ----------------------------------------- |
| Jump to next diagnostic                      | `M-g n`               | `M-x flymake-goto-next-error`             |
| Jump to previous diagnostic                  | `M-g p`               | `M-x flymake-goto-prev-error`             |
| Show diagnostic at point in echo area        | hover                 | `M-x eldoc`                               |
| List all diagnostics in the buffer           | —                     | `M-x flymake-show-buffer-diagnostics`     |
| List all diagnostics in the project          | —                     | `M-x flymake-show-project-diagnostics`    |

### Code actions, symbols

```
M-x eglot-code-actions    ; quick fixes at point
M-x imenu                 ; document symbols
M-x xref-find-apropos     ; workspace symbol search
```

Bind to your own keymaps as you prefer.

### Restart the LSP server

```
M-x awsum-restart-lsp-server
```

Stops the `awsum lsp` process and starts a new one with the same settings (a thin wrapper over `eglot-reconnect`). Useful after a local `stack install` of a new `awsum` build, or to clear any in-memory state on the server. No default keymap; bind via `define-key awsum-ts-mode-map` if you use it often.

## Configuration

The package works with zero configuration. To customize:

```elisp
;; Custom path to the `awsum' binary:
(with-eval-after-load 'awsum
  (setf (alist-get 'awsum-ts-mode eglot-server-programs)
        '(eglot-awsum "/custom/path/awsum" "lsp" "--stdio")))

;; Tweak font-lock level (default 3, set to 4 for variable-use highlighting):
(setq treesit-font-lock-level 4)
```

## Versioning

`awsum-emacs A.B.C` is built and tested against `awsum A.B.C`. Mismatched versions are not supported — at startup the language server compares the package's expected version against its own and shows a notification on mismatch.

## Related

- Compiler (hosts `awsum lsp`): [awsum-lang/awsum](https://github.com/awsum-lang/awsum)
- Tree-sitter grammar: [awsum-lang/tree-sitter-awsum](https://github.com/awsum-lang/tree-sitter-awsum)
- VSCode extension: [awsum-lang/awsum-vscode](https://github.com/awsum-lang/awsum-vscode)
- Zed extension: [awsum-lang/awsum-zed](https://github.com/awsum-lang/awsum-zed)
- IntelliJ Platform plugin: [awsum-lang/awsum-intellij](https://github.com/awsum-lang/awsum-intellij)
- Neovim plugin: [awsum-lang/awsum-nvim](https://github.com/awsum-lang/awsum-nvim)
- Website: [awsum-lang.org](https://awsum-lang.org)

## AI use

This Emacs package is developed with substantial usage of generative AI. Every generated change is reviewed, edited, and accepted by a human before it lands in the repository, and no output is shipped unedited.

## License

Apache 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
