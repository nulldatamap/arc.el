;;; arc.el --- Arc editing mode

;; Copyright (C) 1986, 1987, 1988, 1997, 1998, 2001, 2002, 2003, 2004, 2005,
;;   2006, 2007, 2008  Free Software Foundation, Inc.

;; Author: Bill Rozas <jinx@martigny.ai.mit.edu>
;; Adapted-by: Dave Love <d.love@dl.ac.uk>
;; Adapted-by: Andrew MacDonald <awm@alum.mit.edu>
;; Adapted-by: Eric Hanchrow <offby1@blarg.net>
;; Adapted-by: Siddhartha Kasivajhula <sid@countvajhula.com>
;; Keywords: languages, lisp

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; The major mode for editing Arc-type Lisp code, very similar to
;; the Lisp mode documented in the Emacs manual.

;;; Code:

(require 'lisp-mode)

(defvar arc-mode-syntax-table
  (let ((st (make-syntax-table))
	(i 0))

    ;; Default is atom-constituent.
    (while (< i 256)
      (modify-syntax-entry i "_   " st)
      (setq i (1+ i)))

    ;; Word components.
    (setq i ?0)
    (while (<= i ?9)
      (modify-syntax-entry i "w   " st)
      (setq i (1+ i)))
    (setq i ?A)
    (while (<= i ?Z)
      (modify-syntax-entry i "w   " st)
      (setq i (1+ i)))
    (setq i ?a)
    (while (<= i ?z)
      (modify-syntax-entry i "w   " st)
      (setq i (1+ i)))

    ;; Whitespace
    (modify-syntax-entry ?\t "    " st)
    (modify-syntax-entry ?\n ">   " st)
    (modify-syntax-entry ?\f "    " st)
    (modify-syntax-entry ?\r "    " st)
    (modify-syntax-entry ?\s "    " st)

    ;; These characters are delimiters but otherwise undefined.
    ;; Brackets and braces balance for editing convenience.
    (modify-syntax-entry ?\[ "(]  " st)
    (modify-syntax-entry ?\] ")[  " st)
    (modify-syntax-entry ?{ "(}  " st)
    (modify-syntax-entry ?} "){  " st)
    (modify-syntax-entry ?\| "\" 23bn" st)
    ;; Guile allows #! ... !# comments.
    ;; But SRFI-22 defines the comment as #!...\n instead.
    ;; Also Guile says that the !# should be on a line of its own.
    ;; It's too difficult to get it right, for too little benefit.
    ;; (modify-syntax-entry ?! "_ 2" st)

    ;; Other atom delimiters
    (modify-syntax-entry ?\( "()  " st)
    (modify-syntax-entry ?\) ")(  " st)
    ;; It's used for single-line comments as well as for #;(...) sexp-comments.
    (modify-syntax-entry ?\; "< 2 " st)
    (modify-syntax-entry ?\" "\"   " st)
    (modify-syntax-entry ?' "'   " st)
    (modify-syntax-entry ?` "'   " st)

    ;; Special characters
    (modify-syntax-entry ?, "'   " st)
    (modify-syntax-entry ?@ "'   " st)
    (modify-syntax-entry ?# "' 14b" st)
    (modify-syntax-entry ?\\ "\\   " st)
    st))

(defvar arc-mode-abbrev-table nil)
(define-abbrev-table 'arc-mode-abbrev-table ())

(defvar arc-imenu-generic-expression
      '((nil
	 "^(define\\(\\|-\\(generic\\(\\|-procedure\\)\\|method\\)\\)*\\s-+(?\\(\\sw+\\)" 4)
	("Types"
	 "^(define-class\\s-+(?\\(\\sw+\\)" 1)
	("Macros"
	 "^(\\(defmacro\\|define-macro\\|define-syntax\\)\\s-+(?\\(\\sw+\\)" 2))
  "Imenu generic expression for Arc mode.  See `imenu-generic-expression'.")

(defun arc-mode-variables ()
  (set-syntax-table arc-mode-syntax-table)
  (setq local-abbrev-table arc-mode-abbrev-table)
  (make-local-variable 'paragraph-start)
  (setq paragraph-start (concat "$\\|" page-delimiter))
  (make-local-variable 'paragraph-separate)
  (setq paragraph-separate paragraph-start)
  (make-local-variable 'paragraph-ignore-fill-prefix)
  (setq paragraph-ignore-fill-prefix t)
  (make-local-variable 'fill-paragraph-function)
  (setq fill-paragraph-function 'lisp-fill-paragraph)
  ;; Adaptive fill mode gets in the way of auto-fill,
  ;; and should make no difference for explicit fill
  ;; because lisp-fill-paragraph should do the job.
  (make-local-variable 'adaptive-fill-mode)
  (setq adaptive-fill-mode nil)
  (make-local-variable 'normal-auto-fill-function)
  (setq normal-auto-fill-function 'lisp-mode-auto-fill)
  (make-local-variable 'indent-line-function)
  (setq indent-line-function 'lisp-indent-line)
  (make-local-variable 'parse-sexp-ignore-comments)
  (setq parse-sexp-ignore-comments t)
  (make-local-variable 'outline-regexp)
  (setq outline-regexp ";;; \\|(....")
  (make-local-variable 'comment-start)
  (setq comment-start ";")
  (set (make-local-variable 'comment-add) 1)
  (make-local-variable 'comment-start-skip)
  ;; Look within the line for a ; following an even number of backslashes
  ;; after either a non-backslash or the line beginning.
  (setq comment-start-skip "\\(\\(^\\|[^\\\\\n]\\)\\(\\\\\\\\\\)*\\);+[ \t]*")
  (set (make-local-variable 'font-lock-comment-start-skip) ";+ *")
  (make-local-variable 'comment-column)
  (setq comment-column 40)
  (make-local-variable 'parse-sexp-ignore-comments)
  (setq parse-sexp-ignore-comments t)
  (make-local-variable 'lisp-indent-function)
  (setq lisp-indent-function 'arc-indent-function)
  (setq mode-line-process '("" arc-mode-line-process))
  (set (make-local-variable 'imenu-case-fold-search) t)
  (setq imenu-generic-expression arc-imenu-generic-expression)
  (set (make-local-variable 'imenu-syntax-alist)
	'(("+-*/.<>=?!$%_&~^:" . "w")))
  (set (make-local-variable 'font-lock-defaults)
       '((arc-font-lock-keywords
          arc-font-lock-keywords-1 arc-font-lock-keywords-2)
         nil t (("+-*/.<>=!?$%_&~^:" . "w") (?#. "w 14"))
         beginning-of-defun
         (font-lock-mark-block-function . mark-defun)
         (font-lock-syntactic-face-function
          . arc-font-lock-syntactic-face-function)
         (parse-sexp-lookup-properties . t)
         (font-lock-extra-managed-props syntax-table)))
  (set (make-local-variable 'lisp-doc-string-elt-property)
       'arc-doc-string-elt))

(defvar arc-mode-line-process "")

(defvar arc-mode-map
  (let ((smap (make-sparse-keymap))
	(map (make-sparse-keymap "Arc")))
    (set-keymap-parent smap lisp-mode-shared-map)
    (define-key smap [menu-bar arc] (cons "Arc" map))
    (define-key map [run-arc] '("Run Inferior Arc" . run-arc))
    (define-key map [uncomment-region]
      '("Uncomment Out Region" . (lambda (beg end)
                                   (interactive "r")
                                   (comment-region beg end '(4)))))
    (define-key map [comment-region] '("Comment Out Region" . comment-region))
    (define-key map [indent-region] '("Indent Region" . indent-region))
    (define-key map [indent-line] '("Indent Line" . lisp-indent-line))
    (put 'comment-region 'menu-enable 'mark-active)
    (put 'uncomment-region 'menu-enable 'mark-active)
    (put 'indent-region 'menu-enable 'mark-active)
    smap)
  "Keymap for Arc mode.
All commands in `lisp-mode-shared-map' are inherited by this map.")


;;;###autoload
(defun arc-mode ()
  "Major mode for editing Arc code.
Editing commands are similar to those of `lisp-mode'.

Commands:
Delete converts tabs to spaces as it moves back.
Blank lines separate paragraphs.  Semicolons start comments.
\\{arc-mode-map}
Entry to this mode calls the value of `arc-mode-hook'
if that value is non-nil."
  (interactive)
  (kill-all-local-variables)
  (use-local-map arc-mode-map)
  (setq major-mode 'arc-mode)
  (setq mode-name "Arc")
  (arc-mode-variables)
  (run-mode-hooks 'arc-mode-hook))

(defgroup arc nil
  "Editing Arc code."
  :link '(custom-group-link :tag "Font Lock Faces group" font-lock-faces)
  :group 'lisp)

(defcustom arc-mode-hook nil
  "Normal hook run when entering `arc-mode'.
See `run-hooks'."
  :type 'hook
  :group 'arc)

(defcustom arc-source-path ""
  "The path where the arc distribution was extracted.

This is the directory that contains the file `as.scm`."
  :type 'string
  :group 'arc)

(defconst arc-font-lock-keywords-1
  (eval-when-compile
    (list
     ;;
     ;; Declarations.
     (list 
      (concat "(" (regexp-opt 
		   '("def" "mac" "defop" "defmemo" "defset" "deftem" "set") 
		   t)
	      "\\>"
	      ;; Any whitespace and declared object.
	      "[ \t]*(?"
	      "\\(\\sw+\\)?")
      '(1 font-lock-keyword-face)
      '(2 (cond ((match-beginning 2) font-lock-function-name-face)
		((match-beginning 5) font-lock-variable-name-face)
		(t font-lock-type-face))
	  nil t))
     ))
  "Subdued expressions to highlight in Arc modes.")

(defconst arc-font-lock-keywords-2
  (append arc-font-lock-keywords-1
   (eval-when-compile
     (list
      ;;
      ;; Control structures.
      (cons
       (concat
	"(" (regexp-opt
	     '("fn" "def" "set" "defset" "defop" "deftem" "defmemo"
	       "when" "unless"
	       "do" "while" "until" "only" "each" "if" "=" "for" "repeat"
	       "case" "zap"
	       "let" "with"
	       "mac"
	       "apply" "in"
	       ;; Hannes Haug <hannes.haug@student.uni-tuebingen.de> wants:
	       "and" "or"
	       ;; Stefan Monnier <stefan.monnier@epfl.ch> says don't bother:
	       ;;"quasiquote" "quote" "unquote" "unquote-splicing"
	       "map" "sort") t)
	"\\>") 1)
      )))
  "Gaudy expressions to highlight in Arc modes.")

(defvar arc-font-lock-keywords arc-font-lock-keywords-1
  "Default expressions to highlight in Arc modes.")

(defconst arc-sexp-comment-syntax-table
  (let ((st (make-syntax-table arc-mode-syntax-table)))
    (modify-syntax-entry ?\; "." st)
    (modify-syntax-entry ?\n " " st)
    (modify-syntax-entry ?#  "'" st)
    st))

(put 'lambda 'arc-doc-string-elt 2)
;; Docstring's pos in a `define' depends on whether it's a var or fun def.
(put 'define 'arc-doc-string-elt
     (lambda ()
       ;; The function is called with point right after "define".
       (forward-comment (point-max))
       (if (eq (char-after) ?\() 2 0)))

(defun arc-font-lock-syntactic-face-function (state)
  (when (and (null (nth 3 state))
             (eq (char-after (nth 8 state)) ?#)
             (eq (char-after (1+ (nth 8 state))) ?\;))
    ;; It's a sexp-comment.  Tell parse-partial-sexp where it ends.
    (save-excursion
      (let ((pos (point))
            (end
             (condition-case err
                 (let ((parse-sexp-lookup-properties nil))
                   (goto-char (+ 2 (nth 8 state)))
                   ;; FIXME: this doesn't handle the case where the sexp
                   ;; itself contains a #; comment.
                   (forward-sexp 1)
                   (point))
               (scan-error (nth 2 err)))))
        (when (< pos (- end 2))
          (put-text-property pos (- end 2)
                             'syntax-table arc-sexp-comment-syntax-table))
        (put-text-property (- end 1) end 'syntax-table '(12)))))
  ;; Choose the face to use.
  (lisp-font-lock-syntactic-face-function state))


(defvar calculate-lisp-indent-last-sexp)

;; Copied from lisp-indent-function, but with gets of
;; arc-indent-{function,hook}.
(defun arc-indent-function (indent-point state)
  (let ((normal-indent (current-column)))
    (goto-char (1+ (elt state 1)))
    (parse-partial-sexp (point) calculate-lisp-indent-last-sexp 0 t)
    (if (and (elt state 2)
             (not (looking-at "\\sw\\|\\s_")))
        ;; car of form doesn't seem to be a symbol
        (progn
          (if (not (> (save-excursion (forward-line 1) (point))
                      calculate-lisp-indent-last-sexp))
              (progn (goto-char calculate-lisp-indent-last-sexp)
                     (beginning-of-line)
                     (parse-partial-sexp (point)
					 calculate-lisp-indent-last-sexp 0 t)))
          ;; Indent under the list or under the first sexp on the same
          ;; line as calculate-lisp-indent-last-sexp.  Note that first
          ;; thing on that line has to be complete sexp since we are
          ;; inside the innermost containing sexp.
          (backward-prefix-chars)
          (current-column))
      (let ((function (buffer-substring (point)
					(progn (forward-sexp 1) (point))))
	    method)
	(setq method (or (get (intern-soft function) 'arc-indent-function)
			 (get (intern-soft function) 'arc-indent-hook)))
	(cond ((or (eq method 'defun)
		   (and (null method)
			(> (length function) 3)
			(string-match "\\`def" function)))
	       (lisp-indent-defform state indent-point))
	      ((integerp method)
	       (lisp-indent-specform method state
				     indent-point normal-indent))
	      (method
		(funcall method state indent-point normal-indent)))))))


;;; Let is different in Arc

(defun would-be-symbol (string)
  (not (string-equal (substring string 0 1) "(")))

(defun next-sexp-as-string ()
  ;; Assumes that it is protected by a save-excursion
  (forward-sexp 1)
  (let ((the-end (point)))
    (backward-sexp 1)
    (buffer-substring (point) the-end)))

;; This is correct but too slow.
;; The one below works almost always.
;;(defun arc-let-indent (state indent-point)
;;  (if (would-be-symbol (next-sexp-as-string))
;;      (arc-indent-specform 2 state indent-point)
;;      (arc-indent-specform 1 state indent-point)))

(defun arc-let-indent (state indent-point normal-indent)
  (skip-chars-forward " \t")
  (if (looking-at "[-a-zA-Z0-9+*/?!@$%^&_:~]")
      (lisp-indent-specform 2 state indent-point normal-indent)
    (lisp-indent-specform 1 state indent-point normal-indent)))

;; (put 'begin 'arc-indent-function 0), say, causes begin to be indented
;; like defun if the first form is placed on the next line, otherwise
;; it is indented like any other form (i.e. forms line up under first).

(put 'case 'arc-indent-function 1)
(put 'with 'arc-indent-function 1)
(put 'when 'arc-indent-function 1)
(put 'awhen 'arc-indent-function 1)
(put 'w/stdout 'arc-indent-function 1)
(put 'w/appendfile 'arc-indent-function 1)
(put 'w/stdin 'arc-indent-function 1)
(put 'w/infile 'arc-indent-function 2)
(put 'whilet 'arc-indent-function 2)
(put 'def 'arc-indent-function 2)
(put 'do 'arc-indent-function 0)
(put 'let 'arc-indent-function 'arc-let-indent)



;;; REPL interaction

;; REPL-related code is adapted with minor modifications
;; from racket-mode:
;; https://github.com/greghendershott/racket-mode

(defconst arc--repl-buffer-name/raw
  "Arc REPL"
  "The base buffer name, NOT surrounded in *stars*")

(defconst arc--repl-buffer-name
  (concat "*" arc--repl-buffer-name/raw "*")
  "The actual buffer name as created by comint-mode")

(defun arc--repl-live-p ()
  "Does the Arc REPL buffer exist and have a live Arc process?"
  (comint-check-proc arc--repl-buffer-name))

(defun arc--repl-ensure-buffer-and-process (&optional display)
  "Ensure Arc REPL buffer exists and has live Arc process.

If the Arc process is not already running, it is started.

Non-nil DISPLAY means `display-buffer'.

Never changes selected window."
  (if (arc--repl-live-p)
      (when display
        (display-buffer arc--repl-buffer-name))
    (with-current-buffer
        (let ((default-directory arc-source-path))
          (make-comint arc--repl-buffer-name/raw "racket" nil "-f" "as.scm"))
      (let ((proc (get-buffer-process arc--repl-buffer-name)))
        ;; Display now so users see startup and banner sooner.
        (when display
          (display-buffer (current-buffer)))
        (message "Starting Arc REPL ...")))))

;;;###autoload
(defun arc-repl (&optional noselect)
  "Run the Arc REPL and display its buffer in some window.

If the Arc process is not already running, it is started.

If NOSELECT is not nil, does not select the REPL
window (preserves the originally selected window).

Commands that don't want the REPL to be displayed can instead use
`arc--repl-ensure-buffer-and-process'."
  (interactive "P")
  (arc--repl-ensure-buffer-and-process t)
  (unless noselect
    (select-window (get-buffer-window arc--repl-buffer-name t))))

(defmacro with-arc-repl-buffer (&rest body)
  "Execute the forms in BODY in the REPL buffer.
The value returned is the value of the last form in BODY --
unless no Arc REPL buffer exists, in which case no BODY
forms are evaluated and nil is returned. See also
`with-current-buffer'."
  (declare (indent 0) (debug t))
  (let ((repl-buffer (make-symbol "repl-buffer")))
    `(let ((,repl-buffer (get-buffer arc--repl-buffer-name)))
       (when ,repl-buffer
         (with-current-buffer ,repl-buffer
           ,@body)))))

(defun arc--repl-show-and-move-to-end ()
  "Make the Arc REPL visible, and move point to end.
Keep original window selected."
  (display-buffer arc--repl-buffer-name)
  (save-selected-window
    (select-window (get-buffer-window arc--repl-buffer-name t))
    (comint-show-maximum-output)))

(defun arc--send-to-repl (code)
  "Internal function to send CODE to the Arc REPL for evaluation.

Before sending the code (in string form), calls `arc-repl' and
`arc--repl-forget-errors'.  Also inserts a ?\n at the process
mark so that output goes on a fresh line, not on the same line as
the prompt.

Afterwards call `arc--repl-show-and-move-to-end'."
  (arc-repl t)
  (let ((proc (get-buffer-process arc--repl-buffer-name)))
    (with-arc-repl-buffer
      (save-excursion
        (goto-char (process-mark proc))
        (insert ?\n)
        (set-marker (process-mark proc) (point))))
    (comint-send-string proc code)
    (comint-send-string proc "\n"))
  (arc--repl-show-and-move-to-end))

(defun arc--send-region-to-repl (start end)
  "Internal function to send the region to the Arc REPL."
  (when (and start end)
    (arc--send-to-repl (buffer-substring start end))))

(defun arc--repl-last-sexp-start ()
  (save-excursion
    (condition-case ()
        (progn
          (backward-sexp)
          (if (save-match-data (looking-at "#;"))
              (+ (point) 2)
            (point)))
      (scan-error (user-error "There isn't a complete s-expression before point")))))

(defun arc-send-last-sexp ()
  "Send the previous sexp to the Arc REPL.

When the previous sexp is a sexp comment the sexp itself is sent,
without the #; prefix."
  (interactive)
  (arc--send-region-to-repl (arc--repl-last-sexp-start)
                            (point)))

(defun arc-send-definition ()
  "Send the current definition to the Arc REPL."
  (interactive)
  (save-excursion
    (end-of-defun)
    (let ((end (point)))
      (beginning-of-defun)
      (arc--send-region-to-repl (point) end))))


(provide 'arc)

;; arch-tag: a8f06bc1-ad11-42d2-9e36-ce651df37a90
;;; arc.el ends here
