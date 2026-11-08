;;; awsum-test.el --- Tests for awsum.el  -*- lexical-binding: t; -*-

;;; Commentary:

;; Regression test: a grammar built from a tag other than the pinned one is
;; reinstalled.  A package update moves the pin but leaves the compiled grammar
;; behind, so without this check an upgrade keeps the old grammar for good.
;; Run with `just test'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'awsum)

(defconst awsum-test--pin (nth 2 (assq 'awsum treesit-language-source-alist))
  "The `tree-sitter-awsum' tag this version of the package pins.")

(defun awsum-test--ensure (rev ready)
  "Run `awsum--ensure-grammar' with grammar record REV and a stubbed install.
REV nil means no record.  `treesit-ready-p' answers READY.  Return
\(INSTALLS READY-CALLS RECORD): how often the grammar was installed,
how often `treesit-ready-p' was asked, and the record afterwards."
  (let ((user-emacs-directory (file-name-as-directory (make-temp-file "awsum-test" t)))
        (installs 0)
        (ready-calls 0))
    (unwind-protect
        (progn
          (when rev
            (make-directory (locate-user-emacs-file "tree-sitter") t)
            (with-temp-file (awsum--grammar-rev-file) (insert rev "\n")))
          (cl-letf (((symbol-function 'treesit-install-language-grammar)
                     (lambda (_lang &optional _out-dir)
                       (make-directory (locate-user-emacs-file "tree-sitter") t)
                       (cl-incf installs)))
                    ((symbol-function 'treesit-ready-p)
                     (lambda (&rest _) (cl-incf ready-calls) ready)))
            (awsum--ensure-grammar))
          (list installs ready-calls
                (and (file-readable-p (awsum--grammar-rev-file))
                     (with-temp-buffer
                       (insert-file-contents (awsum--grammar-rev-file))
                       (string-trim (buffer-string))))))
      (delete-directory user-emacs-directory t))))

(ert-deftest awsum-grammar-current-is-kept ()
  (should (equal (awsum-test--ensure awsum-test--pin t) (list 0 1 awsum-test--pin))))

(ert-deftest awsum-grammar-from-other-tag-is-reinstalled-before-loading ()
  ;; `treesit-ready-p' loads the grammar, and Emacs cannot replace a loaded
  ;; grammar, so it must not be asked before the reinstall.
  (should (equal (awsum-test--ensure "v0.0.1" t) (list 1 0 awsum-test--pin))))

(ert-deftest awsum-grammar-without-record-is-reinstalled ()
  ;; Every grammar installed by 0.0.7 or earlier has no record.
  (should (equal (awsum-test--ensure nil t) (list 1 0 awsum-test--pin))))

(ert-deftest awsum-grammar-missing-is-installed ()
  (should (equal (awsum-test--ensure awsum-test--pin nil) (list 1 1 awsum-test--pin))))

(provide 'awsum-test)
;;; awsum-test.el ends here
