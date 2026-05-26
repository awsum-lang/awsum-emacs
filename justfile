_default:
  @ just --list --unsorted

# One-time post-clone setup: installs the prepare-commit-msg hook from
# scripts/git-hooks/ so every commit in this clone auto-adds the DCO
# Signed-off-by trailer. See CONTRIBUTING.md ("Developer Certificate of Origin").
setup-dev:
  #!/bin/sh
  set -eu
  git config core.hooksPath scripts/git-hooks
  chmod +x scripts/git-hooks/prepare-commit-msg
  echo "✅ DCO prepare-commit-msg hook installed for this clone"

# Install this checkout into Emacs's package system via `package-vc-install-from-checkout`.
# Creates a symlink at ~/.emacs.d/elpa/awsum/ and registers the package, so any
# subsequent `emacs file.aww` auto-loads awsum-ts-mode without touching init.el.
install-local:
  #!/bin/sh
  set -eu
  src="{{justfile_directory()}}"
  trap 'rc=$?; [ $rc -ne 0 ] && [ -z "${__quiet_fail:-}" ] && printf "\n\n❌ awsum-emacs install failed (exit %d)\n\n" "$rc"; exit $rc' EXIT

  if ! command -v emacs >/dev/null 2>&1; then
    __quiet_fail=1
    printf '\n❌ Emacs not found on PATH.\n\n'
    exit 1
  fi

  tmp=$(mktemp -t awsum-emacs-install.XXXXXX.el)
  trap 'rm -f "$tmp"; rc=$?; [ $rc -ne 0 ] && [ -z "${__quiet_fail:-}" ] && printf "\n\n❌ awsum-emacs install failed (exit %d)\n\n" "$rc"; exit $rc' EXIT
  cat > "$tmp" << ELISP
  (require 'package)
  (package-initialize)
  (if (assq 'awsum package-alist)
      (message "awsum-emacs is already installed at %s"
               (package-desc-dir (cadr (assq 'awsum package-alist))))
    (package-vc-install-from-checkout "$src" "awsum")
    (message "awsum-emacs installed at %s"
             (package-desc-dir (cadr (assq 'awsum package-alist)))))
  ELISP
  emacs --batch -l "$tmp"

  printf '\n\n✅ awsum-emacs installed.\n'
  printf 'Run `emacs Main.aww` and awsum-ts-mode + eglot activate automatically.\n\n'

# Uninstall the package registered by `install-local`. Source files are untouched.
uninstall-local:
  #!/bin/sh
  set -eu
  trap 'rc=$?; [ $rc -ne 0 ] && [ -z "${__quiet_fail:-}" ] && printf "\n\n❌ awsum-emacs uninstall failed (exit %d)\n\n" "$rc"; exit $rc' EXIT

  if ! command -v emacs >/dev/null 2>&1; then
    __quiet_fail=1
    printf '\n❌ Emacs not found on PATH.\n\n'
    exit 1
  fi

  tmp=$(mktemp -t awsum-emacs-uninstall.XXXXXX.el)
  trap 'rm -f "$tmp"; rc=$?; [ $rc -ne 0 ] && [ -z "${__quiet_fail:-}" ] && printf "\n\n❌ awsum-emacs uninstall failed (exit %d)\n\n" "$rc"; exit $rc' EXIT
  cat > "$tmp" << 'ELISP'
  (require 'package)
  (package-initialize)
  (let ((entry (assq 'awsum package-alist)))
    (if entry
        (progn (package-delete (cadr entry) t)
               (message "awsum-emacs uninstalled"))
      (message "awsum-emacs is not installed; nothing to do")))
  ELISP
  emacs --batch -l "$tmp"

  printf '\n\n✅ awsum-emacs uninstalled.\n\n'

# Byte-compile awsum.el — surfaces unused vars, free refs, deprecated calls.
byte-compile:
  emacs --batch -L . -f batch-byte-compile awsum.el

# Remove byte-compiled artefacts.
clean:
  rm -f *.elc

# Confirm potentially dangerous actions with a specific confirmation input (e.g. version, environment name)
[private]
manual-confirmation-input message required_confirmation:
  #!/bin/sh
  set -eu

  message="{{ message }}"
  required_confirmation="{{ required_confirmation }}"

  echo "$message"
  echo "Type '$required_confirmation' to confirm:"
  read response

  if [ "$response" != "$required_confirmation" ]; then
    echo "Confirmation failed. Exiting..."
    exit 1
  fi

# Tag and push the version currently in awsum.el's (defconst awsum-version ...). Run after the prep PR is merged into main.
release:
  #!/bin/sh
  set -eu
  git checkout main
  git pull
  version=$(grep -m1 '^(defconst awsum-version' awsum.el | sed 's/.*"\(.*\)".*/\1/')
  just manual-confirmation-input "About to tag and push v$version" "$version"
  git tag -a "v$version" -m "Release $version"
  git push origin "v$version"
