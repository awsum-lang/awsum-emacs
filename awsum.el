;;; awsum.el --- Awsum language support  -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Vladimir Logachev

;; Author: Vladimir Logachev
;; Maintainer: Vladimir Logachev
;; Version: 0.0.4
;; Package-Requires: ((emacs "29.1"))
;; URL: https://github.com/awsum-lang/awsum-emacs
;; Keywords: languages

;; This file is not part of GNU Emacs.

;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Emacs support for the Awsum programming language (`.aww' files).
;;
;; Provides a `awsum-ts-mode' major mode and wires it to the bundled
;; `awsum lsp' language server through the built-in `eglot' client.
;; Syntax highlighting and outline are powered by tree-sitter.
;;
;; The `awsum' binary must be on `exec-path' (`PATH').  The tree-sitter
;; grammar is installed automatically from
;; https://github.com/awsum-lang/tree-sitter-awsum on first use via
;; `treesit-install-language-grammar' (requires a C compiler).
;;
;; `awsum-emacs A.B.C' is built against `awsum A.B.C'.  Mismatched
;; versions surface a warning from the server on startup.

;;; Code:

(require 'eglot)
(require 'treesit)

(defgroup awsum nil
  "Awsum language support."
  :group 'languages
  :prefix "awsum-")

(defconst awsum-version "0.0.4"
  "Version of `awsum-emacs', shipped to the language server as
`expectedAwsumVersion' so the server can warn on mismatch.  Must
match the version of the `awsum' compiler binary on `PATH'.")


;;; Syntax table

(defvar awsum-ts-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; `--' starts a line comment that runs to end-of-line.
    (modify-syntax-entry ?-  ". 12" table)
    (modify-syntax-entry ?\n ">"    table)
    ;; Strings.
    (modify-syntax-entry ?\" "\""   table)
    (modify-syntax-entry ?\\ "\\"   table)
    ;; Symbol constituents.
    (modify-syntax-entry ?_  "_"    table)
    table)
  "Syntax table for `awsum-ts-mode'.")


;;; Eglot integration

(defclass eglot-awsum (eglot-lsp-server) ()
  "Eglot server subclass for `awsum-ts-mode'.

Exists so we can override `eglot-initialization-options' to ship
the version-pin protocol contract without affecting other Eglot
servers.")

(cl-defmethod eglot-initialization-options ((_server eglot-awsum))
  "Init options sent to `awsum lsp' in the LSP `initialize' request.

`:expectedAwsumVersion' is the protocol contract — the server compares
it against its own version and emits a `window/showMessage' warning
on mismatch.  `:preferButtonsOverLinks' tells the server to use
`window/showMessageRequest' (actionable buttons) instead of inline
links in messages, which Eglot maps to the user's `completing-read'
front-end."
  `(:expectedAwsumVersion ,awsum-version
    :preferButtonsOverLinks t))

(add-to-list 'eglot-server-programs
             '(awsum-ts-mode . (eglot-awsum "awsum" "lsp" "--stdio")))


;;;###autoload
(defun awsum-restart-lsp-server ()
  "Restart the Awsum LSP server for the current buffer.

Delegates to `eglot-reconnect', which stops the `awsum lsp' process and
starts a fresh one with the same `eglot-initialization-options'.  Useful
after a local `stack install' of a new `awsum' build, or to clear any
in-memory state on the server."
  (interactive)
  (unless (eglot-current-server)
    (user-error "No Awsum LSP server attached to this buffer"))
  (eglot-reconnect (eglot-current-server))
  (message "awsum: LSP server restart triggered"))


;;; Tree-sitter grammar

(add-to-list 'treesit-language-source-alist
             '(awsum "https://github.com/awsum-lang/tree-sitter-awsum"
                     "v0.0.4"
                     "src"))

(defun awsum--ensure-grammar ()
  "Install the Awsum tree-sitter grammar if it isn't already available.

Called from `awsum-ts-mode' on activation.  If the grammar can't be
installed (no C compiler, no network), surface a `message' and let
the mode start without tree-sitter — Eglot still works."
  (unless (treesit-ready-p 'awsum t)
    (condition-case err
        (treesit-install-language-grammar 'awsum)
      (error
       (message
        "awsum-emacs: tree-sitter grammar install failed (%s).  \
Highlighting unavailable; LSP features still work.  Re-run with \
`M-x treesit-install-language-grammar RET awsum RET' to retry."
        (error-message-string err))))))


;;; Font-lock rules (port of tree-sitter-awsum/queries/highlights.scm)

(defvar awsum-ts-mode--font-lock-settings
  (treesit-font-lock-rules
   :language 'awsum
   :feature 'comment
   '([(line_comment) (block_comment)] @font-lock-comment-face)

   :language 'awsum
   :feature 'string
   '((string) @font-lock-string-face)

   :language 'awsum
   :feature 'number
   '((integer) @font-lock-number-face)

   :language 'awsum
   :feature 'keyword
   '(["import" "type" "empty" "case" "of" "do" "let" "in"] @font-lock-keyword-face)

   :language 'awsum
   :feature 'operator
   '(["->" "<-" "|>" "++" "|" "=" ":" "\\"] @font-lock-operator-face)

   :language 'awsum
   :feature 'bracket
   '(["(" ")"] @font-lock-bracket-face)

   :language 'awsum
   :feature 'delimiter
   '("." @font-lock-delimiter-face)

   ;; Type positions.  The grammar's `_type` is a choice (union / arrow /
   ;; app / atom), and `_type_atom` is an alias — bare type references
   ;; like `Int32` appear directly as `upper_id` in the field of whichever
   ;; type-shape node contains them.  Each field listed explicitly because
   ;; treesit queries can't say "any descendant in a type position".
   :language 'awsum
   :feature 'type
   '((type_decl name: (upper_id) @font-lock-type-face)
     (empty_type_decl name: (upper_id) @font-lock-type-face)
     (type_decl parameter: (lower_id) @font-lock-variable-name-face)
     (signature type: (upper_id) @font-lock-type-face)
     (arrow_type domain: (upper_id) @font-lock-type-face)
     (arrow_type codomain: (upper_id) @font-lock-type-face)
     (union_type left: (upper_id) @font-lock-type-face)
     (union_type right: (upper_id) @font-lock-type-face)
     (type_app callee: (upper_id) @font-lock-type-face)
     (type_app arg: (upper_id) @font-lock-type-face))

   :language 'awsum
   :feature 'constructor
   '((con_def name: (upper_id) @font-lock-type-face)
     (pattern_constructor (upper_id) @font-lock-type-face))

   :language 'awsum
   :feature 'definition
   '((signature name: (lower_id) @font-lock-function-name-face)
     (fun_def name: (lower_id) @font-lock-function-name-face)
     (fun_def parameter: (lower_id) @font-lock-variable-name-face)
     (lambda parameter: (lower_id) @font-lock-variable-name-face)
     (operator_name) @font-lock-function-name-face)

   :language 'awsum
   :feature 'pattern
   '((pattern_ascribe (lower_id) @font-lock-variable-name-face))

   :language 'awsum
   :feature 'module
   '((import_decl module: (module_path (upper_id) @font-lock-constant-face))
     (qname (upper_id) @font-lock-constant-face))

   :language 'awsum
   :feature 'function-call
   '((qname (lower_id) @font-lock-function-call-face))

   :language 'awsum
   :feature 'variable
   '((app (lower_id) @font-lock-variable-use-face))

   ;; `_`-prefixed identifiers — intentional-unused convention.  `:override
   ;; t' makes this win over `@variable.name' / `@variable.use' captures of
   ;; the same node, so `_x` always reads as dimmed-comment regardless of
   ;; whether it's a param, a let-bind, or a constructor reference.
   :language 'awsum
   :feature 'unused
   :override t
   '(((lower_id) @font-lock-comment-face
      (:match "^_" @font-lock-comment-face))
     ((upper_id) @font-lock-comment-face
      (:match "^_" @font-lock-comment-face))))
  "Tree-sitter font-lock rules for `awsum-ts-mode'.  Port of
`highlights.scm' from `tree-sitter-awsum'.")

(defvar awsum-ts-mode--font-lock-feature-list
  '((comment string)
    (keyword type constructor unused)
    (definition module function-call pattern operator number)
    (variable bracket delimiter))
  "Per-level feature groups for `treesit-font-lock-level'.  Levels are
cumulative: level 2 includes level 1.  The default level is 3.  `unused'
lives at level 2 so the `_`-prefix dim-render is always on when any
non-minimal highlighting is on — it's a semantic signal, not decoration.")


;;; Major mode

;;;###autoload
(define-derived-mode awsum-ts-mode prog-mode "Awsum"
  "Major mode for editing Awsum source files (`.aww').

Thin layer over the built-in `eglot' LSP client (talking to
`awsum lsp --stdio') and the built-in `treesit' tree-sitter
runtime (grammar from `tree-sitter-awsum')."
  :syntax-table awsum-ts-mode-syntax-table
  :group 'awsum
  (setq-local comment-start "-- "
              comment-end ""
              comment-start-skip "--+[ \t]*")
  (awsum--ensure-grammar)
  (when (treesit-ready-p 'awsum t)
    (treesit-parser-create 'awsum)
    (setq-local treesit-font-lock-settings awsum-ts-mode--font-lock-settings
                treesit-font-lock-feature-list awsum-ts-mode--font-lock-feature-list)
    (treesit-major-mode-setup))
  (eglot-ensure))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.aww\\'" . awsum-ts-mode))

(provide 'awsum)

;;; awsum.el ends here
