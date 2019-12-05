;;; package --- Summary

;;; Commentary:

;;; xcode-mode.el --- A minor mode for EMACS to perform Xcode like actions.

;; Copyright (C) 2016 John Buckley

;; Author: John Buckley <john@olivetoat.com>
;; Keywords: conveniences
;; Version: 0.1

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;; TODO: Update this and submit to melpa (name??)

;;; Code:

(defgroup xcode-mode nil
  "A minor mode for building, running & testing Xcode projects."
  :group 'emacs)

(defcustom xcode-mode-xcpretty t
  "If non-nil uses xcpretty (if available) to format xcodebuild output."
  :type 'boolean
  :group 'xcode-mode)

;; TODO: xcode-mode-xcpretty-color variable (default nil)

(defvar xcode-mode-map
  (make-sparse-keymap)
  "Keymap for xcode.")

(define-key xcode-mode-map
  (kbd"C-c xa") 'xcode-mode-archive)

(define-key xcode-mode-map
  (kbd"C-c xy") 'xcode-mode-analyze)

(define-key xcode-mode-map
  (kbd"C-c xb") 'xcode-mode-build)

(define-key xcode-mode-map
  (kbd"C-c xr") 'xcode-mode-run)

(define-key xcode-mode-map
  (kbd"C-c xc") 'xcode-mode-clean)

(define-key xcode-mode-map
  (kbd"C-c xu") 'xcode-mode-test)

(define-key xcode-mode-map
  (kbd"C-c x1") 'xcode-mode-test-one)

(define-key xcode-mode-map
  (kbd"C-c xd") 'xcode-mode-search-docs)

;;;###autoload
(define-minor-mode xcode-mode
  "Minor mode to perform xcode like actions."
  :lighter " xcode"
  :keymap xcode-mode-map)

(defvar xcode-mode--scheme-history nil)
(defvar xcode-mode--test-history nil)

(defun xcode-mode-build(scheme)
  "Build SCHEME."
  (interactive (list (read-string "Build scheme: " (car xcode-mode--scheme-history) '(xcode-mode--scheme-history . 1))))
  (message (format "Building %s" scheme))
  (xcode-mode--compile (format "xcodebuild -scheme %s" scheme) xcode-mode-xcpretty)
  )

(defun xcode-mode-clean(scheme)
  "Run a build clean for SCHEME."
  (interactive (list (read-string "Clean scheme: " (car xcode-mode--scheme-history) '(xcode-mode--scheme-history . 1))))
  (message (format "Cleaning %s" scheme))
  (if (string= scheme "")
      (xcode-mode--compile "xcodebuild clean" xcode-mode-xcpretty)
    (xcode-mode--compile (format "xcodebuild clean -scheme %s" scheme) xcode-mode-xcpretty))
  )

(defun xcode-mode-analyze(scheme)
  "Run an analysis build for SCHEME."
  (interactive (list (read-string "Analyze scheme: " (car xcode-mode--scheme-history) '(xcode-mode--scheme-history . 1))))
  (message (format "Analyzing %s" scheme))
  (xcode-mode--compile (format "xcodebuild analyze -scheme %s" scheme) xcode-mode-xcpretty)
  )

(defun xcode-mode-archive(scheme)
  "Run an archive build for SCHEME."
  (interactive (list (read-string "Archive scheme: " (car xcode-mode--scheme-history) '(xcode-mode--scheme-history . 1))))
  (message (format "Archiving %s" scheme))
  (xcode-mode--compile (format "xcodebuild archive -scheme %s" scheme) xcode-mode-xcpretty)
  )

(defun xcode-mode-test(scheme)
  "Run all test methods for SCHEME."
  (interactive (list (read-string "Test scheme: " (car xcode-mode--scheme-history) '(xcode-mode--scheme-history . 1))))
  (message (format "Testing %s" scheme))
  (let ((cmd (format "xcodebuild test -scheme %s" scheme)))
    (if xcode-mode-xcpretty
        (xcode-mode--compile (concat cmd " | xcpretty -k"))
      (xcode-mode--compile cmd))))

(defun xcode-mode-test-one(target)
  "Run a single test case for TARGET."
  (interactive (list (read-string "Test one [Scheme/Class/Method]: " (car xcode-mode--test-history) '(xcode-mode--test-history . 1))))
  (message (format "Testing %s" target))
  (let ((cmd (format "xcodebuild test -scheme %s -only-testing:%s" (car (split-string target "/")) target)))
    (if xcode-mode-xcpretty
        (xcode-mode--compile (concat cmd " | xcpretty -k"))
      (xcode-mode--compile cmd)))
  )

(defun xcode-run()
  "Run the active scheme in the active workspace."
  (interactive)
  (message "Running...")
  (shell-command "osascript -e 'tell application \"Xcode\" to run active workspace document'")
  )

(defun xcode-search-docs(str)
  "Search for STR in Xcode documentation browser.
  
Note: requires that Emacs has assistive access to set the search string in the Documentation search field."
  (interactive "P")
  (let ((thing (thing-at-point 'symbol))
        (cmd "osascript -e 'tell application \"System Events\"
		tell process \"Xcode\"
			set frontmost to true
			keystroke \"0\" using {shift down, command down}
			set searchField to text field 1 of (group 4 of (toolbar 1 of window 1 ))
			set value of searchField to \"%s\"
		end tell
	end tell'"))
    (shell-command (format cmd (read-string "Search docs: " thing)))))

(defun xcode-mode--project-directory()
  "Get project directory.
Uses `locate-dominating-file`, falling back to the current directory."
  (or (locate-dominating-file
       default-directory
       (lambda (dir) (directory-files dir nil ".+\\.xcodeproj")))
      default-directory))

(defun xcode-mode--compile (command &optional xcpretty)
  "Compile COMMAND in the current Xcode project.
If XCPRETTY is non-nil, pipes output through xcpretty."
  (let ((default-directory (xcode-mode--project-directory)))
    (if (xcode-mode--use-xcpretty)
        (compile (concat command " | xcpretty --no-color"))
      (compile command))))

(defun xcode-mode--use-xcpretty ()
  "Return t if compile should use xcpretty."
  (and xcode-mode-xcpretty
       (executable-find "xcpretty")))

(provide 'xcode-mode)

;;; xcode-mode.el ends here
