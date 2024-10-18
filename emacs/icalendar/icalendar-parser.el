;;; icalendar-parser.el --- Parse iCalendar grammar  -*- lexical-binding:t -*-

;; Copyright (C) 2024 Richard Lawrence

;; Author: Richard Lawrence <rwl@recursewithless.net>
;; Created: October 2024
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

;; This file defines regular expressions, functions and macros that
;; implement the iCalendar grammar according to RFC5545.
;;
;; iCalendar data is grouped into *components*, such as events or
;; to-do items. Each component contains one or more *content lines*,
;; which each contain a *property* name and its *value*, and possibly
;; also property *parameters* with additional data that affects the
;; interpretation of the property.
;;
;; The macros ical:define-parameter, ical:define-property and
;; ical:define-component each create rx-style regular expressions and
;; a parsing function for one of these categories in the grammar and
;; are used to define the particular parameters, properties and
;; components in the standard. These parsing functions and regular
;; expressions are also used to create entries for
;; `font-lock-keywords', which are gathered into several constants
;; along the way, and used to provide syntax highlighting in
;; icalendar-mode.el. A number of other regular expressions which
;; encode basic categories of the grammar are also defined.
;;
;; According to RFC5545, iCalendar content lines longer than 75 octets
;; should be *folded* by inserting extra line breaks and leading
;; whitespace to continue the line. Such lines must be *unfolded*
;; before they can be parsed. This file also defines functions for
;; folding and unfolding lines. Unfolding can only reliably happen
;; before Emacs decodes a region of text, because decoding potentially
;; replaces the CR-LF line endings which terminate content lines.
;; Programs that can control when decoding happens should use the
;; stricter `ical:unfold-undecoded-region' to unfold text; programs
;; that must work with decoded data should use the looser
;; `ical:unfold-region'. `ical:fold-region' will fold content lines
;; using line breaks appropriate to the buffer's coding system.

;;; Code:

(defun ical:unfold-undecoded-region (start end &optional buffer)
  "Unfold an undecoded region in BUFFER between START and END.
If omitted, BUFFER defaults to the current buffer.

'Unfolding' means removing the whitespace characters inserted to
continue lines longer than 75 octets (see `ical:fold-region' for
the folding operation). RFC5545 specifies these whitespace
characters to be a CR-LF sequence followed by a single space or
tab character. Unfolding can only be done reliably before a
region is decoded, since decoding potentially replaces CR-LF line
endings. This function searches strictly for CR-LF sequences, and
will fail if they have already been replaced, so it should only
be called with a region that has not yet been decoded."
  (with-current-buffer (or buffer (current-buffer))
    (with-restriction start end
      (goto-char (point-min))
      (while (re-search-forward (rx (seq "\r\n" (or " " "\t")))
                                nil t)
        (replace-match "" nil nil)))))

(defun ical:unfold-region (start end &optional buffer)
  "Unfold a region in BUFFER between START and END. If omitted,
BUFFER defaults to the current buffer.

'Unfolding' means removing the whitespace characters inserted to
continue lines longer than 75 octets (see `ical:fold-region' for
the folding operation).

WARNING: Unfolding can only be done reliably before text is
decoded, since decoding potentially replaces CR-LF line endings.
Unfolding an already-decoded region could lead to unexpected
results, such as displaying multibyte characters incorrectly,
depending on the contents and the coding system used.

This function attempts to do the right thing even if the region
is already decoded. If it is still undecoded, it is better to
call `ical:unfold-undecoded-region' directly instead, and decode
it afterward."
  ;; TODO: also make this a command so it can be run manually?
  (with-current-buffer (or buffer (current-buffer))
    (let ((was-multibyte enable-multibyte-characters)
          (start-char (position-bytes start))
          (end-char (position-bytes end)))
      ;; we put the buffer in unibyte mode and later restore its
      ;; previous state, so that if the buffer was already multibyte,
      ;; any multibyte characters where line folds broke up their
      ;; bytes can be reinterpreted:
      (set-buffer-multibyte nil) 
      (with-restriction start-char end-char
        (goto-char (point-min))
        ;; since we can't be sure that line folds have a leading CR
        ;; in already-decoded regions, do the best we can:
        (while (re-search-forward (rx (seq (zero-or-one "\r") "\n"
                                           (or " " "\t")))
                                  nil t) 
          (replace-match "" nil nil)))                
      ;; restore previous state, possibly reinterpreting characters:
      (set-buffer-multibyte was-multibyte))))

(defun ical:unfolded-buffer-from-region (start end &optional buffer)
  "Create a new buffer with the same contents as the region between
START and END (in BUFFER, if provided) and perform line unfolding
in the new buffer with `ical:unfold-region'. That function can in
some cases have undesirable effects; see its docstring. If BUFFER
is visiting a file, it may be better to reload its contents from
that file and perform line unfolding before decoding; see
`ical:unfolded-buffer-from-file'. Returns the new buffer."
  (let* ((old-buffer (or buffer (current-buffer)))
         (contents (with-current-buffer old-buffer
                     (buffer-substring start end)))
         (old-cs (with-current-buffer old-buffer
                   buffer-file-coding-system))
         (uf-buffer (generate-new-buffer
               (concat (buffer-name old-buffer)
                             "~UNFOLDED")))) ;; TODO: again, move to modeline?
    (with-current-buffer uf-buffer
      (insert contents)
      (ical:unfold-region (point-min) (point-max))
      ;; ensure we'll use CR-LF line endings on write, even if they weren't
      ;; in the source data. The standard also says UTF-8 is the default
      ;; encoding, so use 'prefer-utf-8-dos when last-coding-system-used
      ;; is nil.
      (setq buffer-file-coding-system
            (if last-coding-system-used 
                (coding-system-change-eol-conversion last-coding-system-used
                                                     'dos)
              'prefer-utf-8-dos)))
    uf-buffer))

(defun ical:unfolded-buffer-from-buffer (buffer)
  "Create a new buffer with the same contents as BUFFER and perform
line unfolding with `ical:unfold-region'. That function can in
some cases have undesirable effects; see its docstring. If BUFFER
is visiting a file, it may be better to reload its contents from
that file and perform line unfolding before decoding; see
`ical:unfolded-buffer-from-file'. Returns the new buffer."
  (with-current-buffer buffer
    (ical:unfolded-buffer-from-region (point-min) (point-max) buffer)))

(defun ical:unfolded-buffer-from-file (filename &optional visit beg end)
    "Create a new buffer with the contents of FILENAME and perform
line unfolding with `ical:unfold-undecoded-region', then decode
the buffer, setting an appropriate value for
`buffer-file-coding-system'. Optional arguments VISIT, BEG, END
are as in `insert-file-contents'. Returns the new buffer."
    (unless (and (file-exists-p filename)
                 (file-readable-p filename))
      (error "File cannot be read: %s" filename))
    ;; TODO: instead of messing with the buffer name, it might be more
    ;; useful to keep track of the folding state in a variable and
    ;; display it somewhere else in the mode line
    (let ((uf-buffer (generate-new-buffer (concat (file-name-nondirectory filename)
                                                  "~UNFOLDED"))))
      (with-current-buffer uf-buffer 
        (set-buffer-multibyte nil)
        (insert-file-contents-literally filename visit beg end t)
        (ical:unfold-undecoded-region (point-min) (point-max))
        (set-buffer-multibyte t)
        (decode-coding-inserted-region (point-min) (point-max) filename)
        ;; ensure we'll use CR-LF line endings on write, even if they weren't
        ;; in the source data. The standard also says UTF-8 is the default
        ;; encoding, so use 'prefer-utf-8-dos when last-coding-system-used
        ;; is nil. FIXME: for some reason, this doesn't seem to run at all!
        (setq buffer-file-coding-system
              (if last-coding-system-used 
                  (coding-system-change-eol-conversion last-coding-system-used
                                                       'dos)
                'prefer-utf-8-dos))
        ;; restore buffer name after renaming by set-visited-file-name:
        (let ((bname (buffer-name)))
          (set-visited-file-name filename t)
          (rename-buffer bname)))
      uf-buffer))

(defun ical:fold-region (begin end &optional use-tabs)
  "Fold all content lines in the region longer than 75 octets.

'Folding' means inserting a line break and a single space
character at the beginning of the new line. If USE-TABS is
non-nil, insert a tab character instead of a single space.
 
RFC5545 specifies that lines longer than 75 *octets* (excluding
the line-ending CR-LF sequence) must be folded, and allows that
some implementations might fold lines in the middle of a
multibyte character. This function takes care not to do that in a
buffer where `enable-multibyte-characters' is non-nil, and only
folds between character boundaries. If the buffer is in unibyte
mode, however, and contains undecoded multibyte data, it may fold
lines in the middle of a multibyte character."
  ;; TODO: also make this a command so it can be run manually?
  (save-excursion
    (goto-char begin)
    (when (not (bolp))
      (let ((inhibit-field-text-motion t))
        (beginning-of-line)))
    (let ((bol (point))
          (eol (make-marker))
          (reg-end (make-marker))
          (line-fold
           (concat
            ;; if \n will be translated to \r\n on save (EOL type 1,
            ;; "DOS"), just insert \n, otherwise the full fold sequence:
            ;; FIXME: is buffer-file-coding-system the only relevant one here?
            ;; What if the buffer is not visiting a file, but has come from a
            ;; process, represents a mime part in an email, etc.?
            (if (eq 1 (coding-system-eol-type buffer-file-coding-system))
                "\n"
              "\r\n")
            ;; leading whitespace after line break:
            (if use-tabs "\t" " ")))
          char-after-fold)
      (set-marker reg-end end)
      (while (< bol reg-end)
        (let ((inhibit-field-text-motion t))
          (end-of-line))
        (set-marker eol (point))
        (when (< 75 (- (position-bytes (marker-position eol))
                       (position-bytes bol)))
          (goto-char
           ;; the max of 75 excludes the two CR-LF
           ;; characters we're about to add:
           (byte-to-position (+ 75 (position-bytes bol))))
          (insert line-fold)
          (set-marker eol (point))) 
        (setq bol (goto-char (1+ eol)))))))

(defun ical:contains-folded-lines-p ()
  "Determine whether the current buffer contains folded content
lines that should be unfolded for parsing and display purposes.
If it does, return the position at the end of the first fold."
  (save-excursion
    (goto-char (point-min))
    (re-search-forward (rx (seq line-start (or " " "\t")))
                       nil t)))

(defun ical:contains-unfolded-lines-p ()
  "Determine whether the current buffer contains long content lines
that should be folded before saving or transmitting. If it does,
return the position at the beginning of the first line that
requires folding."
  (save-excursion
    (goto-char (point-min))
    (let ((bol (point))
          (eol (make-marker)))
      (catch 'unfolded-line
        (while (< bol (point-max))
          (let ((inhibit-field-text-motion t))
            (end-of-line))
          (set-marker eol (point))
          ;; the max of 75 excludes the two CR-LF characters
          ;; after position eol:
          (when (< 75 (- (position-bytes (marker-position eol))
                         (position-bytes bol)))
            (throw 'unfolded-line bol))
          (setq bol (goto-char (1+ eol))))
        nil))))


;; Section 3.1: Content lines

;; Regexp constants for parsing:
(rx-define ical:iana-token
  (one-or-more (any alnum "-")))

(rx-define ical:x-name
  (seq "X-"
      ;; Group 1: vendorid:
      (zero-or-one (group (>= 3 (any alnum))) "-")
      ;; Group 2: name:
      (group (one-or-more (any alnum "-")))))

(rx-define ical:name
  (or ical:iana-token ical:x-name))

(rx-define ical:crlf
  (seq #x12 #xa))

(rx-define ical:control
  ;; All the controls except HTAB
  (any (#x00 . #x08) (#x0A . #x1F) #x7F))

;; TODO: double check that "whitespace" and "nonascii" classes actually
;; correspond to the ranges in the standards
(rx-define ical:safe-char
  ;; Any character except ical:control, ?\", ?\;, ?:, ?,
  (any whitespace #x21  (#x23 . #x2B) (#x2D . #x39) (#x3C . #x7E) nonascii))

(rx-define ical:qsafe-char
  ;; Any character except ical:control and ?"
  (any whitespace #x21 (#x23 . #x7E) nonascii))

(rx-define ical:quoted-string
  (seq ?\" (zero-or-more ical:qsafe-char) ?\"))

(rx-define ical:paramtext
  (zero-or-more ical:safe-char))

(rx-define ical:param-name
  (or ical:iana-token ical:x-name))

(rx-define ical:param-value
  (or ical:paramtext ical:quoted-string))

(rx-define ical:value-char
  (any whitespace (#x21 . #x7E) nonascii))

(rx-define ical:value
  (zero-or-more ical:value-char))

;; some helpers for brevity, not defined in the standard:
(rx-define ical:comma-list (item-rx)
  (seq item-rx
       (zero-or-more (seq ?, item-rx))))

(rx-define ical:semicolon-list (item-rx)
  (seq item-rx
       (zero-or-more (seq ?\; item-rx))))


;; Section 3.3: Property Value Data Types

;; Note: These definitions are here (out of order) because a few of them
;; are already required for property parameter definitions (section 3.2) below.

;; from https://www.rfc-editor.org/rfc/rfc4288#section-4.2:
(rx-define ical:mimetype-regname
  (** 1 127 (any alnum ?! ?# ?$ ?& ?. ?+ ?- ?^ ?_)))

(rx-define ical:mimetype
  (seq ical:mimetype-regname "/" ical:mimetype-regname))

;; TODO: see https://www.rfc-editor.org/rfc/rfc5646#section-2.1
(rx-define ical:rfc5646-lang
  (one-or-more (any alnum ?-))) 

;; from https://www.rfc-editor.org/rfc/rfc4648#section-4
(rx-define ical:base64char
  (any (?A . ?Z) (?a . ?z) (?0 . ?9) ?+ ?/))

(rx-define ical:binary
  (seq (zero-or-more (= 4 ical:base64char))
       (zero-or-one (or (seq (= 2 ical:base64char "=="))
                        (seq (= 3 ical:base64char "="))))))

(rx-define ical:boolean
  (or "TRUE"
      "FALSE"))

(rx-define ical:cal-address
  ical:uri) 

(rx-define ical:quoted-cal-address
  (seq ?\" ical:cal-address ?\"))

(rx-define ical:quoted-cal-address-list
  (seq ical:quoted-cal-address
       (zero-or-more (seq "," ical:quoted-cal-address))))

;; Date and Time:

(rx-define ical:year
  (= 4 digit))

(rx-define ical:month
  (= 2 digit))

(rx-define ical:mday
  (= 2 digit))

(rx-define ical:date
  (seq ical:year ical:month ical:mday))

(rx-define ical:time
  (seq (= 6 digit) (zero-or-one ?Z))) 

(rx-define ical:date-time
  (seq ical:date ?T ical:time))

(rx-define ical:dur-second
  (seq (one-or-more digit) ?S))

(rx-define ical:dur-minute
  (seq (one-or-more digit) ?M (zero-or-one ical:dur-second)))

(rx-define ical:dur-hour
  (seq (one-or-more digit) ?H (zero-or-one ical:dur-minute)))

(rx-define ical:dur-day
  (seq (one-or-more digit) ?D))

(rx-define ical:dur-week
  (seq (one-or-more digit) ?W))

(rx-define ical:dur-time
  (seq ?T (or ical:dur-hour ical:dur-minute ical:dur-second)))

(rx-define ical:dur-date
  (seq ical:dur-day (zero-or-one ical:dur-time)))

(rx-define ical:dur-value
  (seq
   (zero-or-one (or ?+ ?-))
   ?P
   (or ical:dur-date ical:dur-time ical:dur-week)))

(rx-define ical:float
  (seq
   (zero-or-one (or ?+ ?-))
   (one-or-more digit)
   (zero-or-one (seq ?. (one-or-more digit)))))

(rx-define ical:integer
  (seq
   (zero-or-one (or ?+ ?-))
   (one-or-more digit)))

(rx-define ical:period
  (or
   (seq ical:date-time "/" ical:date-time)
   (seq ical:date-time "/" ical:dur-value)))


;; Recurrence rules:
(rx-define ical:freq
   (or "SECONDLY" "MINUTELY" "HOURLY" "DAILY" "WEEKLY" "MONTHLY" "YEARLY"))

(rx-define ical:weekday
   (or "SU" "MO" "TU" "WE" "TH" "FR" "SA"))

(rx-define ical:ordwk
  (** 1 2 digit)) ; 1 to 53

(rx-define ical:weekdaynum
   (seq (zero-or-one (seq (zero-or-one (or ?+ ?-))
                          ical:ordwk)) 
        ical:weekday))

(rx-define ical:weeknum
  (seq (zero-or-one (or ?+ ?-))
       ical:ordwk))

(rx-define ical:monthdaynum
  (seq (zero-or-one (or ?+ ?-))
       (** 1 2 digit))) ; 1 to 31

(rx-define ical:monthnum
  (seq (zero-or-one (or ?+ ?-))
       (** 1 2 digit))) ; 1 to 12

(rx-define ical:yeardaynum
  (seq (zero-or-one (or ?+ ?-))
       (** 1 3 digit))) ; 1 to 366

(rx-define ical:recur-rule-part
  (or (seq "FREQ" "=" ical:freq)
      (seq "UNTIL" "=" (or ical:date ical:date-time))
      (seq "COUNT" "=" (one-or-more digit))
      (seq "INTERVAL" "=" (one-or-more digit))
      (seq "BYSECOND" "=" (ical:comma-list (** 1 2 digit))) ; 0 to 60
      (seq "BYMINUTE" "=" (ical:comma-list (** 1 2 digit))) ; 0 to 59
      (seq "BYHOUR" "=" (ical:comma-list (** 1 2 digit))) ; 0 to 23
      (seq "BYDAY" "=" (ical:comma-list ical:weekdaynum))
      (seq "BYMONTHDAY" "=" (ical:comma-list ical:monthdaynum))
      (seq "BYYEARDAY" "=" (ical:comma-list ical:yeardaynum))
      (seq "BYWEEKNO" "=" (ical:comma-list ical:weeknum))
      (seq "BYMONTH" "=" (ical:comma-list ical:monthnum))
      (seq "BYSETPOS" "=" (ical:comma-list ical:yeardaynum))
      (seq "WKST" "=" ical:weekday)))

(rx-define ical:recur
  (ical:semicolon-list ical:recur-rule-part))


;; Text
(rx-define ical:escaped-char
   (seq ?\\ (or ?\\ ?\; ?, ?N ?n)))

(rx-define ical:text-safe-char
  (not (or ?\" ?\; ?: ?\\ ?, ical:control))) ;; TODO: is this correct?

(rx-define ical:text
  (zero-or-more (or ical:text-safe-char ?: ?\" ical:escaped-char)))

;; URIs; see https://www.rfc-editor.org/rfc/rfc3986
(rx-define ical:uri
  ;; TODO: parse more structure here? This regex only scans for
  ;; characters allowed by RFC3986. This is quite permissive and will
  ;; match e.g. most whole content lines, though it's still less
  ;; permissive than the regex suggested in the standard (see Appendix
    ;; B), which despite parsing more structure will also match the empty string.
    (one-or-more
    (any alnum ?- ?. ?_ ?~                   ; unreserved chars
            ?: ?/ ?? ?# ?\[ ?\] ?@              ; gen-delims
            ?! ?$ ?& ?' ?\( ?\) ?* ?+ ?, ?\; ?= ; sub-delims
            ?%)))                               ; for %-encoding

    (rx-define ical:quoted-uri
    (seq ?\" ical:uri ?\"))

    (rx-define ical:utc-offset
    (seq (or ?+ ?-)
        (or (= 4 digit) ;; TODO: as with times above, these could be narrower
            (= 6 digit))))


;; Section 3.2: Property Parameters

(defconst ical:params-font-lock-keywords nil ;; populated by ical:define-param
  "Entries for iCalendar property parameters in `font-lock-keywords'.")

(defmacro ical:define-param (symbolic-name doc param-name value &rest kwargs)
  "Define iCalendar parameter PARAM-NAME.

Generates a regular expression named SYMBOLIC-NAME to match the parameter,
which can then be used in other (rx-style) regular expressions.
  Group 1 of this regex matches PARAM-NAME.
  Group 2 matches VALUE, the regex that specifies a correct value
    for this parameter according to RFC5545.
  Group 3, if matched, contains any parameter value which does
    *not* match VALUE, and is incorrect according to the standard.
A parsing function that uses this regular expression is also defined.

KWARGS, if given, should be a plist with any of the following keys:
  :name-face - a face symbol for highlighting the property name
               (default: ical:parameter-name)
  :value-face - a face symbol for highlighting valid property values
               (default: ical:parameter-value)
  :warn-face - a face symbol for highlighting invalid property values
                   (default: ical:warning)"
  (let ((full-doc (format "%s=... %s" param-name doc))
        (name-face (or (plist-get kwargs :name-face) 'ical:parameter-name))
        (value-face (or (plist-get kwargs :value-face) 'ical:parameter-value))
        (warn-face (or (plist-get kwargs :warn-face) 'ical:warning))
        (parser-name (intern (concat "icalendar-parse-"
                                       (downcase param-name)
                                       "-parameter"))))

    ;; TODO: is it ok to use variable-documentation here?
    (put symbolic-name 'variable-documentation full-doc)
    `(progn
       ;; Regex which matches:
       ;; Group 1: the parameter name,
       ;; Group 2: correct values of the parameter, and 
       ;; Group 3: incorrect values up to the next parameter (for syntax warnings)
       ;; TODO: do we need strict and liberal variants??
       (rx-define ,symbolic-name
         (seq ";"
              (group-n 1 ,param-name)
              "="
              (or (group-n 2 ,value)
                  (group-n 3 ical:param-value))))

       (defun ,parser-name (limit)
         ,(format "Parser for %s parameter (defined by define-param)" param-name)
         (re-search-forward (rx ,symbolic-name) limit t))
       
       ;; Generate an entry for font-lock-keywords in icalendar-mode:
       (push (quote (,parser-name
                     (1 (quote ,name-face) t t)
                     (2 (quote ,value-face) t t)
                     (3 (quote ,warn-face) t t)))
             ical:params-font-lock-keywords)
       ;; TODO: integrate param-name with eldoc in icalendar-mode
       ;; TODO: use regex to parse into elisp data structure
       )))

(ical:define-param ical:altrepparam "Alternate text representation (URI)"
                   "ALTREP"
                   ical:quoted-uri
                   :value-face ical:uri)

(ical:define-param ical:cnparam "Common Name"
                   "CN"
                   ical:param-value)

(ical:define-param ical:cutypeparam "Calendar User Type"
                   "CUTYPE"
                   (or "INDIVIDUAL"   ; An individual (Default)
                       "GROUP"        ; A group of individuals
                       "RESOURCE"     ; A physical resource
                       "ROOM"         ; A room resource
                       "UNKNOWN"      ; Otherwise not known
                       ical:x-name    ; Experimental type
                       ical:iana-token)
                   :value-face ical:keyword)

(ical:define-param ical:delfromparam "Delegators (address URIs)"
                   "DELEGATED-FROM"
                   ical:quoted-cal-address-list
                   :value-face ical:uri) 

(ical:define-param ical:deltoparam "Delegatees (address URIs)"
                   "DELEGATED-TO"
                   ical:quoted-cal-address-list
                   :value-face ical:uri)

(ical:define-param ical:dirparam "Directory Entry Reference (URI)"
                   "DIR"
                   ical:quoted-uri
                   :value-face ical:uri)

(ical:define-param ical:encodingparam "Inline Encoding"
                   "ENCODING"
                   (or "8BIT" "BASE64")
                   :value-face ical:keyword)

(ical:define-param ical:fmttypeparam "Format Type (Mimetype per RFC4288)"
                   "FMTTYPE"
                   ical:mimetype) 

(ical:define-param ical:fbtypeparam "Free/Busy Time Type"
                   "FBTYPE"
                   (or "FREE"
                       "BUSY-UNAVAILABLE"
                       "BUSY-TENTATIVE"
                       "BUSY"
                       ical:x-name ; experimental free/busy type.
                       ical:iana-token) ; other IANA-registered type
                   :value-face ical:keyword) 

(ical:define-param ical:languageparam "Language tag (per RFC5646)"
                   "LANGUAGE"
                   ical:rfc5646-lang)

(ical:define-param ical:memberparam "Group or List Membership (address URIs)"
                   "MEMBER"
                   ical:quoted-cal-address-list
                   :value-face ical:uri)

(ical:define-param ical:partstatparam "Participation status"
                   "PARTSTAT"
                   (or "NEEDS-ACTION" ; Default
                       "ACCEPTED"   
                       "DECLINED"  
                       "TENTATIVE"
                       "DELEGATED"
                       "COMPLETED"
                       "IN-PROCESS"
                       ical:x-name    
                       ical:iana-token)
                   :value-face ical:keyword)

(ical:define-param ical:rangeparam "Recurrence Identifier Range"
                   "RANGE"
                   "THISANDFUTURE"
                   :value-face ical:keyword) ; only accepted value

(ical:define-param ical:trigrelparam "Alarm Trigger Relationship"
                   "RELATED"
                   (or "START" "END")
                   :value-face ical:keyword)

(ical:define-param ical:reltypeparam "Relationship type"
                   "RELTYPE"
                   (or "PARENT"    ; Default
                       "CHILD"     
                       "SIBLING"   
                       ical:iana-token 
                       ical:x-name)
                   :value-face ical:keyword)

(ical:define-param ical:roleparam "Participation role"
                   "ROLE"
                   (or "CHAIR"             
                       "REQ-PARTICIPANT"   ; Indicates a participant whose
                                        ; participation is required (default)
                       "OPT-PARTICIPANT"   ; Indicates a participant whose
                                        ; participation is optional
                       "NON-PARTICIPANT"   ; Indicates a participant who
                                        ; is copied for information
                                        ; purposes only
                       ical:x-name         ; Experimental role
                       ical:iana-token)    ; Other IANA role
                   :value-face ical:keyword)   

(ical:define-param ical:rsvpparam "RSVP expectation (boolean)"
                   "RSVP"
                   ical:boolean  ; default is false
                   :value-face ical:keyword) 

(ical:define-param ical:sentbyparam "Sent by"
                   "SENT-BY"
                   ical:quoted-cal-address
                   :value-face ical:uri)

(ical:define-param ical:tzidparam "Time Zone identifier."
                   "TZID"
                   (seq (zero-or-one "/") ical:paramtext))

(ical:define-param ical:valuetypeparam "Property value data type"
                   "VALUE"
                   (or "BINARY"
                       "BOOLEAN"
                       "CAL-ADDRESS"
                       "DATE-TIME"
                       "DATE"
                       "DURATION"
                       "FLOAT"
                       "INTEGER"
                       "PERIOD"
                       "RECUR"
                       "TEXT"
                       "TIME"
                       "URI"
                       "UTC-OFFSET"
                       ical:x-name
                       ical:iana-token)
                   :value-face ical:keyword)

(rx-define ical:other-param-safe
  ;; we use this rx to skip params when matching properties and
  ;; their values. Thus we *don't* capture the param names and param values
  ;; in numbered groups here, which would clobber the groups of the enclosing
  ;; expression.
  (seq ";"
       (or ical:iana-token ical:x-name)
       "="
       (ical:comma-list ical:param-value)))


;; Properties:

(defconst ical:properties-font-lock-keywords
  nil ;; populated by ical:define-property
  "Entries for iCalendar properties in `font-lock-keywords'.")

(defmacro ical:define-property (symbolic-name doc property-name value &rest kwargs)
  "Define iCalendar property PROPERTY-NAME.

Generates a regular expression named SYMBOLIC-NAME to match the
property, which can then be used in other (rx-style) regular
expressions.
  Group 1 of this regex matches PROPERTY-NAME.
  Group 2 matches VALUE, the regex that specifies a correct value
   for this property according to RFC5545.
  Group 3, if matched, contains any property value which does
   *not* match VALUE, and is incorrect according to the standard.
A parsing function that uses this regular expression is also defined.

KWARGS, if given, should be a plist with any of the following keys:
  :name-face - a face symbol for highlighting the property name
               (default: ical:property-name)
  :value-face - a face symbol for highlighting valid property values
               (default: ical:property-value)
  :warn-face - a face symbol for highlighting invalid property values
               (default: ical:warning)"
  (let ((full-doc (format "%s:... %s" property-name doc))
        (name-face (or (plist-get kwargs :name-face) 'ical:property-name))
        (value-face (or (plist-get kwargs :value-face) 'ical:property-value))
        (warn-face (or (plist-get kwargs :warn-face) 'ical:warning))
        (parser-name (intern (concat "icalendar-parse-"
                                     (downcase property-name)
                                     "-property"))))
    ;; TODO: is it ok to use variable-documentation here?
    (put symbolic-name 'variable-documentation full-doc)
    `(progn
       ;; Regex which matches:
       ;; Group 1: the property name,
       ;; Group 2: correct values of the property, and 
       ;; Group 3: incorrect values up to end-of-line (for syntax warnings)
       (rx-define ,symbolic-name
         (seq line-start
              (group-n 1 ,property-name)
              ;; TODO: define parameters to match too? capture these?
              (zero-or-more ical:other-param-safe)
              ":"
              (or (group-n 2 ,value)
                  (group-n 3 (zero-or-more any)))
              line-end))

       (defun ,parser-name (limit)
         ,(format "Parser for %s property (defined by define-property)"
                  property-name)
         (re-search-forward (rx ,symbolic-name) limit t))

       ;; Generate an entry for font-lock-keywords in icalendar-mode:
       (push (quote (,parser-name
                     (1 (quote ,name-face) t t)
                     (2 (quote ,value-face) t t)
                     (3 (quote ,warn-face) t t)))
             ical:properties-font-lock-keywords)
       ;; TODO: integrate property-name with eldoc in icalendar-mode
       )))

;; Section 3.7: Calendar Properties

(ical:define-property ical:calscale "Calendar scale"
                      "CALSCALE"
                      ;; only allowed value:
                      "GREGORIAN"
                      :value-face ical:keyword)

(ical:define-property ical:method "Method"
                      "METHOD"
                      ical:iana-token)

(ical:define-property ical:prodid "Product Identifier"
                      "PRODID"
                      ical:text)

(ical:define-property ical:version "Version (2.0 corresponds to RFC5545)"
                      "VERSION"
                      (or "2.0"
                                        ; minver ; maxver
                          (seq ical:iana-token ?\; ical:iana-token)))

;; Section 3.8:
;; Section 3.8.1: Descriptive Component Properties

(ical:define-property ical:attach "Attachment (URI or encoded binary)"
                      "ATTACH"
                      (or ical:uri
                          ical:binary))

(ical:define-property ical:categories "Categories"
                      "CATEGORIES"
                      (ical:comma-list ical:text))

(ical:define-property ical:class "(Access) Classification"
                      "CLASS"
                      (or "PUBLIC" ; Default
                          "PRIVATE"
                          "CONFIDENTIAL"
                          ical:iana-token
                          ical:x-name)
                      :value-face ical:keyword)

(ical:define-property ical:comment "Comment to calendar user"
                      "COMMENT"
                      ical:text)

(ical:define-property ical:description "Description"
                      "DESCRIPTION"
                      ical:text)

(ical:define-property ical:geo "Global position (latitude;longitude)"
                      "GEO"
                      (seq ical:float ?\; ical:float)
                      :value-face ical:numeric-types)

(ical:define-property ical:location "Location"
                      "LOCATION"
                      ical:text)

(ical:define-property ical:percent-complete "Percent Complete"
                      "PERCENT-COMPLETE"
                      ical:integer
                      :value-face ical:numeric-types)

(ical:define-property ical:priority "Priority (0-9, default 0)"
                      "PRIORITY"
                      ical:integer
                      :value-face ical:numeric-types)

(ical:define-property ical:resources "Resources"
                      "RESOURCES"
                      (ical:comma-list ical:text))

(ical:define-property ical:status "Status"
                      "STATUS"
                      ;; Note that this does NOT allow arbitrary text:
                      (or "TENTATIVE"
                          "CONFIRMED"
                          "CANCELLED"
                          "NEEDS-ACTION"
                          "COMPLETED"
                          "IN-PROCESS"
                          "DRAFT"
                          "FINAL")
                      :value-face ical:keyword)

(ical:define-property ical:summary "Summary"
                      "SUMMARY"
                      ical:text)

;; Section 3.8.2: Date and Time Component Properties

(ical:define-property ical:completed "Completed"
                      "COMPLETED"
                      ical:date-time
                      :value-face ical:date-time-types)

(ical:define-property ical:dtend "Date-Time End"
                      "DTEND"
                      (or ical:date-time ; Default
                          ical:date)
                      :value-face ical:date-time-types)

(ical:define-property ical:dtstamp "Date-Time Stamp"
                      "DTSTAMP"
                      ical:date-time
                      :value-face ical:date-time-types)

(ical:define-property ical:due "Due"
                      "DUE"
                      (or ical:date-time ; Default
                          ical:date)
                      :value-face ical:date-time-types)

(ical:define-property ical:dtstart "Date-Time Start"
                      "DTSTART"
                      (or ical:date-time ; Default
                          ical:date)
                      :value-face ical:date-time-types)

(ical:define-property ical:duration "Duration"
                      "DURATION"
                      ical:dur-value
                      :value-face ical:date-time-types)

(ical:define-property ical:freebusy "Free/Busy Time"
                      "FREEBUSY"
                      (ical:comma-list ical:period)
                      :value-face ical:date-time-types)

(ical:define-property ical:transp "Time Transparency"
                      "TRANSP"
                      ;; Note that this does NOT allow arbitrary text:
                      (or "TRANSPARENT"
                          "OPAQUE")
                      :value-face ical:keyword)

;; Section 3.8.3: Time Zone Component Properties

(ical:define-property ical:tzid "Time Zone Identifier"
                      "TZID"
                      (seq (zero-or-one "/") ical:text))

(ical:define-property ical:tzname "Time Zone Name"
                      "TZNAME"
                      ical:text)

(ical:define-property ical:tzoffsetfrom "Time Zone Offset (prior to this TZ observance)"
                      "TZOFFSETFROM"
                      ical:utc-offset
                      :value-face ical:date-time-types)

(ical:define-property ical:tzoffsetto "Time Zone Offset (in this TZ observance)"
                      "TZOFFSETTO"
                      ical:utc-offset
                      :value-face ical:date-time-types)

(ical:define-property ical:tzurl "Time Zone Url"
                      "TZURL"
                      ical:uri
                      :value-face ical:uri)

;; Section 3.8.4: Relationship Component Properties

(ical:define-property ical:attendee "Attendee"
                      "ATTENDEE"
                      ical:cal-address
                      :value-face ical:uri)

(ical:define-property ical:contact "Contact"
                      "CONTACT"
                      ical:text)

(ical:define-property ical:organizer "Organizer"
                      "ORGANIZER"
                      ical:cal-address
                      :value-face ical:uri)

(ical:define-property ical:recurrence-id "Recurrence ID"
                      "RECURRENCE-ID"
                      (or ical:date-time ; Default
                          ical:date)
                      :value-face ical:date-time-types)

(ical:define-property ical:related-to "Related To (component UID)"
                      "RELATED-TO"
                      ical:text)

(ical:define-property ical:url "Uniform Resource Locator"
                      "URL"
                      ical:uri
                      :value-face ical:uri)

(ical:define-property ical:uid "Unique Identifier"
                      "UID"
                      ical:text)

;; Section 3.8.5: Recurrence Component Properties

(ical:define-property ical:exdate "Exception Date-Times"
                      "EXDATE"
                      (ical:comma-list (or ical:date-time
                                           ical:date))
                      :value-face ical:date-time-types)

(ical:define-property ical:rdate "Recurrence Date-Times"
                      "RDATE"
                      (ical:comma-list (or ical:date-time
                                           ical:date
                                           ical:period))
                      :value-face ical:date-time-types)

(ical:define-property ical:rrule "Recurrence Rule"
                      "RRULE"
                      ical:recur
                      :value-face ical:recurrence-rule)

;; Section 3.8.6: Alarm Component Properties

(ical:define-property ical:action "Action (when alarm triggered)"
                      "ACTION"
                      (or "AUDIO"
                          "DISPLAY"
                          "EMAIL"
                          ical:iana-token
                          ical:x-name)
                      :value-face ical:keyword)

(ical:define-property ical:repeat "Repeat Count (after initial trigger)"
                      "REPEAT"
                      ical:integer  ; Default: 0
                      :value-face ical:numeric-types)

(ical:define-property ical:trigger "Trigger"
                      "TRIGGER"
                      (or ical:dur-value
                          ical:date-time)
                      :value-face ical:date-time-types) 

;; Section 3.8.7: Change Management Component Properties

(ical:define-property ical:created "Date-Time Created"
                      "CREATED"
                      ical:date-time
                      :value-face ical:date-time-types)

                                        ; another DTSTAMP, to represent creation time or last update,
                                        ; depending on presence of METHOD.
                                        ; TODO: is this different than the one above??

(ical:define-property ical:last-modified "Last Modified"
                      "LAST-MODIFIED"
                      ical:date-time
                      :value-face ical:date-time-types)

(ical:define-property ical:sequence "Sequence Number"
                      "SEQUENCE"
                      ical:integer ; Default: 0
                      :value-face ical:numeric-types)

;; Section 3.8.8: Miscellaneous Component Properties
;; IANA and X- properties should be parsed but can be ignored:
(rx-define ical:iana-or-x-name-property
  (seq line-start
       (group-n 1 (or ical:iana-token ical:x-name)
       ;; TODO: define parameters to match too? capture these?
       (zero-or-more (seq ?\; ical:other-param-safe))
       ":"
       (group-n 2 ical:value)
       line-end)))

(defconst ical:ignored-properties-font-lock-keywords
  `((,(rx ical:iana-or-x-name-property) (1 'ical:ignored keep)
                                        (2 'ical:ignored keep)))
  "Entries for iCalendar ignored properties in `font-lock-keywords'.")

(ical:define-property ical:request-status "Request status"
                      "REQUEST-STATUS"
                      (seq
                       ;; statcode: hierarchical status code
                       (seq (one-or-more digit)
                            (** 1 2 (seq ?. (one-or-more digit))))
                       ?\;
                       ;; statdesc: status description
                       ical:text
                       ;; exdata: exception data
                       (zero-or-one (seq ?\; ical:text))))


;; Section 3.6: Calendar Components

(defconst ical:components-font-lock-keywords
  nil ;; populated by ical:define-component
  "Entries for iCalendar components in `font-lock-keywords'.")

(defmacro ical:define-component (symbolic-name doc component-name &rest kwargs)
  "Define iCalendar component COMPONENT-NAME.

Generates a regular expression named SYMBOLIC-NAME to match the component,
which can then be used in other (rx-style) regular expressions.
  Group 1 of this regex matches the \"BEGIN\" or \"END\" keyword that marks
    a component boundary.
  Group 2 matches COMPONENT-NAME, a string that specifies a name
    for this component according to RFC5545.
A parsing function that uses this regular expression is also defined.

KWARGS, if given, should be a plist with any of the following keys:
  :keyword-face - a face symbol for highlighting the BEGIN/END keyword
               (default: ical:keyword)
  :name-face - a face symbol for highlighting the component name
               (default: ical:component-name)"
  ;; TODO: use params to encode property constraints
  (let ((full-doc (format "%s:... %s" component-name doc))
        (keyword-face (or (plist-get kwargs :keyword-face) 'ical:keyword))
        (name-face (or (plist-get kwargs :name-face) 'ical:component-name))
        (parser-name (intern (concat "icalendar-parse-"
                                     (downcase component-name)
                                     "-component"))))
    ;; TODO: is it ok to use variable-documentation here?
    (put symbolic-name 'variable-documentation full-doc)
    `(progn
       ;; Regex which matches:
       ;; Group 1: BEGIN or END, and
       ;; Group 2: the component name
       (rx-define ,symbolic-name
         (seq line-start
              (group-n 1 (or "BEGIN" "END"))
              ":"
              (group-n 2 ,component-name)
              line-end))

       (defun ,parser-name (limit)
         ,(format "Parser for %s component (defined by define-component)"
                  component-name)
           (re-search-forward (rx ,symbolic-name) limit t))

       ;; Generate an entry for font-lock-keywords in icalendar-mode:
       (push (quote (,parser-name
               (1 (quote ,keyword-face) t t)
               (2 (quote ,name-face) t t)))
             ical:components-font-lock-keywords)
       ;; TODO: integrate component-name with eldoc in icalendar-mode
       )))

(ical:define-component ical:vevent "Event Component"
                       "VEVENT")

(ical:define-component ical:todo "To-Do Component"
                       "VTODO")

(ical:define-component ical:vjournal "Journal Component"
                       "VJOURNAL")

(ical:define-component ical:vfreebusy "Free/Busy Component"
                       "VFREEBUSY")

(ical:define-component ical:vtimezone "Time Zone Component"
                       "VTIMEZONE")

(ical:define-component ical:standard "Standard-Time Subcomponent"
                       "STANDARD")

(ical:define-component ical:daylight "Daylight-Time Subcomponent"
                       "DAYLIGHT")

(ical:define-component ical:valarm "Alarm Component"
                       "VALARM")

;; TODO: technically VCALENDAR is not a "component", but for the purposes
;; of syntax highlighting, it looks just like one, so we define it as such here:
(ical:define-component ical:vcalendar "Calendar Object"
                       "VCALENDAR")

(provide 'icalendar-parser)

;; Local Variables:
;; read-symbol-shorthands: (("ical:" . "icalendar-"))
;; End:
;;; icalendar-parser.el ends here
