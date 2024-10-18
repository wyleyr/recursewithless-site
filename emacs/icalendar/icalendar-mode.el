;;; icalendar-mode.el --- Major mode for iCalendar format  -*- lexical-binding: t; -*-   
;;; 

;; Copyright (C) 2024 Richard Lawrence

;; Author: Richard Lawrence <rwl@recursewithless.net>
;; Keywords: calendar

;; This file is not part of GNU Emacs. But the Author hopes it might
;; be one day! 

;; This file is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This file defines icalendar-mode, a major mode for editing
;; iCalendar data. It defines a syntax table, faces, hooks, and
;; commands for the mode and sets up syntax highlighting via
;; font-lock-mode. Syntax highlighting uses the entries for
;; font-lock-keywords already gathered in icalendar-parser.el, which
;; see.

;; When activated, icalendar-mode offers to unfold content lines if
;; necessary, and switch to a new buffer containing the unfolded data;
;; see `ical:maybe-switch-to-unfolded-buffer'. This is because the
;; parsing facilities, and thus syntax highlighting, assume that
;; content lines have already been unfolded. When a buffer is saved,
;; icalendar-mode also offers to fold long content if necessary, as
;; required by RFC5545; see `ical:before-save-checks'.

;;; Code:
(require 'icalendar-parser)


;; Faces:
(defgroup ical:faces
  '((ical:property-name custom-face)
    (ical:property-value custom-face)
    (ical:parameter-name custom-face)
    (ical:parameter-value custom-face)
    (ical:component-name custom-face)
    (ical:keyword custom-face)
    (ical:binary-data custom-face)
    (ical:date-time-types custom-face)
    (ical:numeric-types custom-face)
    (ical:recurrence-rule custom-face)
    (ical:warning custom-face)
    (ical:ignored custom-face))
  "Faces for icalendar-mode.") ; TODO: :group

(defface ical:property-name
  '((default . (:inherit font-lock-keyword-face)))
  "Face for iCalendar property names")

(defface ical:property-value
  '((default . (:inherit default)))
  "Face for iCalendar property values")

(defface ical:parameter-name
  '((default . (:inherit font-lock-property-name-face)))
  "Face for iCalendar parameter names")

(defface ical:parameter-value
  '((default . (:inherit font-lock-property-use-face)))
  "Face for iCalendar parameter values")

(defface ical:component-name
  '((default . (:inherit font-lock-constant-face)))
  "Face for iCalendar component names")

(defface ical:keyword
  '((default . (:inherit font-lock-keyword-face)))
  "Face for other iCalendar keywords")

(defface ical:binary-data
  '((default . (:inherit font-lock-comment-face)))
  "Face for iCalendar values that represent binary data")

(defface ical:date-time-types
  '((default . (:inherit font-lock-type-face)))
  "Face for iCalendar values that represent dates, date-times,
durations, periods, and UTC offsets")

(defface ical:numeric-types
  '((default . (:inherit ical:property-value-face)))
  "Face for iCalendar values that represent integers, floats, and geolocations")

(defface ical:recurrence-rule
  '((default . (:inherit font-lock-type-face)))
  "Face for iCalendar recurrence rule values")

(defface ical:uri
  '((default . (:inherit ical:property-value-face :underline t)))
  "Face for iCalendar values that are URIs (including URLs and mail addresses)")

(defface ical:warning
  '((default . (:inherit font-lock-warning-face)))
  "Face for iCalendar syntax errors")

(defface ical:ignored
  '((default . (:inherit font-lock-comment-face)))
  "Face for iCalendar syntax which is parsed but ignored")

(defvar icalendar-mode-syntax-table
    (let ((st (make-syntax-table)))
      ;; Characters for which the standard syntax table suffices:
      ;; ; (punctuation): separates some property values, and property parameters
      ;; " (string): begins and ends string values
      ;; : (punctuation): separates property name (and parameters) from property values
      ;; , (punctuation): separates values in a list
      ;; CR, LF (whitespace): content line endings
      ;; space (whitespace): when at the beginning of a line, continues the previous line

      ;; Characters which need to be adjusted from the standard syntax table:
      ;; = is punctuation, not a symbol constituent:
      (modify-syntax-entry ?= ".   " st)
      ;; / is punctuation, not a symbol constituent:
      (modify-syntax-entry ?/ ".   " st)
      st)
    "Syntax table used in `icalendar-mode'.")

(defvar ical:font-lock-keywords
  (append ical:params-font-lock-keywords
          ical:properties-font-lock-keywords
          ical:components-font-lock-keywords
          ical:ignored-properties-font-lock-keywords)
  "Value of `font-lock-keywords' for icalendar-mode.")

(defvar ical:mode-hook nil
  "Hook run when activating `icalendar-mode'.")

(add-to-list 'auto-mode-alist '("\\.ics\\'" . icalendar-mode))

;; TODO: is there a corresponding list by mimetype for buffers
;; displaying message parts? Thought I saw this somewhere...

(defun ical:switch-to-unfolded-buffer ()
  "Switch to viewing the contents of the current buffer in a new
buffer where content lines have been unfolded.

'Folding' means inserting a line break and a single whitespace
character to continue lines longer than 75 octets; 'unfolding'
means removing the extra whitespace inserted by folding. The
iCalendar standard (RFC5545) requires folding lines when
serializing data to iCalendar format, and unfolding before
parsing it. In icalendar-mode, folded lines may not have proper
syntax highlighting; this command allows you to view iCalendar
data with proper syntax highlighting, as the parser sees it.

If the current buffer is visiting a file, this function will
offer to save the buffer first, and then reload the contents from
the file, performing unfolding with `ical:unfold-undecoded-region'
before decoding it. This is the most reliable way to unfold lines.

If it is not visiting a file, it will unfold the new buffer
with `ical:unfold-region'. This can in some cases have
undesirable effects (see its docstring), so the original contents
are preserved unchanged in the current buffer.

In both cases, after switching to the new buffer, this command
offers to kill the original buffer.

It is recommended to turn off `auto-fill-mode' when viewing an
unfolded buffer, so that filling does not interfere with syntax
highlighting. This function offers to disable `auto-fill-mode' if
it is enabled in the new buffer; consider using
`visual-line-mode' instead."
  (interactive) 
  (when (and buffer-file-name (buffer-modified-p))
    (when (y-or-n-p (format "Save before reloading from %s?"
                            (file-name-nondirectory buffer-file-name)))
      (save-buffer)))
  (let ((old-buffer (current-buffer))
        (mmode major-mode)
        (uf-buffer (if buffer-file-name
                       (ical:unfolded-buffer-from-file buffer-file-name)
                     (ical:unfolded-buffer-from-buffer (current-buffer)))))
    (switch-to-buffer uf-buffer)
    ;; restart original major mode, in case the new buffer is
    ;; still in fundamental-mode: TODO: is this necessary?
    (funcall mmode) 
    (when (y-or-n-p (format "Unfolded buffer is shown. Kill %s?"
                            (buffer-name old-buffer)))
      (kill-buffer old-buffer))
    (when (and auto-fill-function
               (y-or-n-p "Disable auto-fill-mode?"))
      (auto-fill-mode -1))))

(defun ical:maybe-switch-to-unfolded-buffer ()
  "Check for folded lines and ask for confirmation before calling
`ical:switch-to-unfolded-buffer', which see.

This function is intended to be run via `icalendar-mode-hook'
when `icalendar-mode' is activated."
  (interactive)
  (if (ical:contains-folded-lines-p)
      (when (y-or-n-p "Buffer contains folded lines; unfold in new buffer?")
        (ical:switch-to-unfolded-buffer))
    ;; No need for unfolding, just inform the user:
    (message "Buffer does not contain any lines to unfold")))

(add-hook 'ical:mode-hook 'ical:maybe-switch-to-unfolded-buffer)

(defun ical:before-save-checks ()
  "Offer to change coding system and fold content lines in the
current buffer when saving a buffer in `icalendar-mode'.

The iCalendar standard requires CR-LF line endings, so if
`buffer-file-coding-system' does not use a coding system which
specifies them, this command offers to switch to a corresponding
coding system which does.

'Folding' means inserting a line break and a single whitespace
character to continue lines longer than 75 octets. The iCalendar
standard requires folding lines when serializing data to
iCalendar format, so if the buffer contains unfolded lines, this
command asks you whether you want to fold them."
  (interactive)
  (when (eq major-mode 'icalendar-mode)
    (let* ((cs buffer-file-coding-system)
           (suggested-cs (if cs (coding-system-change-eol-conversion cs 'dos)
                           'prefer-utf-8-dos)))
      (when (and (not (coding-system-equal cs suggested-cs))
                 (y-or-n-p
                  (format "Current coding system %s does not use CR-LF line endings. Change to %s for save?" cs suggested-cs)))
        (set-buffer-file-coding-system suggested-cs))
      (when (and (ical:contains-unfolded-lines-p)
                 (y-or-n-p "Fold content lines before saving?"))
        (ical:fold-region (point-min) (point-max))))))

(add-hook 'before-save-hook 'ical:before-save-checks)

(define-derived-mode icalendar-mode text-mode "iCalendar"
  "Major mode for viewing and editing iCalendar (RFC5545) data.

This mode provides syntax highlighting for iCalendar components,
properties, values, and property parameters, and commands to deal
with folding and unfolding iCalendar content lines.

'Folding' means inserting whitespace characters to continue long
lines; 'unfolding' means removing the extra whitespace inserted
by folding. The iCalendar standard requires folding lines when
serializing data to iCalendar format, and unfolding before
parsing it.

Thus icalendar-mode's syntax highlighting is designed to work
with unfolded lines. When icalendar-mode is activated, it will
offer to unfold lines; see `ical:switch-to-unfolded-buffer'. It
will also offer to fold lines when saving a buffer to a file; see
`ical:before-save-checks'. That function also offers to convert
the line endings in the file to CR-LF, as the standard requires."
  :group 'icalendar
  :syntax-table icalendar-mode-syntax-table
  ;; TODO: Keymap?
  ;; TODO: buffer-local variables?
  ;; TODO: indent-line-function and indentation variables
  ;; TODO: mode-specific menu and context menus 
  ;; TODO: eldoc integration
  ;; TODO: completion of keywords 
  ;; TODO: hook for folding in change-major-mode-hook?
  (progn
    (setq font-lock-defaults '(ical:font-lock-keywords nil t))))

(provide 'icalendar-mode)

;; Local Variables:
;; read-symbol-shorthands: (("ical:" . "icalendar-"))
;; End:
;;; icalendar-mode.el ends here
