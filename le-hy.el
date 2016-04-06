;;; le-hy.el --- lispy support for Hy. -*- lexical-binding: t -*-

;; Copyright (C) 2016 Oleh Krehel

;; This file is not part of GNU Emacs

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;

;;; Code:

(require 'hy-mode)
(require 'inf-lisp)

(defun lispy--hy-proc ()
  (let ((proc-name "hy"))
    (if (process-live-p proc-name)
        (get-process proc-name)
      (get-buffer-process
       (make-comint proc-name "hy")))))

(defun lispy--comint-eval (command)
  "Collect output of COMMAND without changing point."
  (let ((command-output-begin nil)
        (str nil)
        (last-cmd nil)
        (last-cmd-with-prompt nil)
        (inhibit-field-text-motion t)
        (buffer (process-buffer (lispy--hy-proc))))
    (with-current-buffer buffer
      ;; save the last command and delete the old prompt
      (beginning-of-line)
      (setq last-cmd-with-prompt
            (buffer-substring (point) (line-end-position)))
      (setq last-cmd (replace-regexp-in-string
                      "=> " "" last-cmd-with-prompt))
      (delete-region (point) (line-end-position))
      ;; send the command
      (setq command-output-begin (point))
      (comint-simple-send (get-buffer-process (current-buffer))
                          command)
      ;; collect the output
      (goto-char (point-max))
      (while (not (save-excursion
                    (let ((inhibit-field-text-motion t))
                      (goto-char (point-max))
                      (beginning-of-line)
                      (looking-at
                       "[. ]*=> \\s-*$"))))
        (accept-process-output (get-buffer-process buffer))
        (goto-char (point-max)))
      ;; save output to string
      (forward-line -1)
      (setq str (buffer-substring-no-properties command-output-begin (line-end-position)))
      ;; delete the output from the command line
      (delete-region command-output-begin (point-max))
      ;; restore prompt and insert last command
      (goto-char (point-max))
      (delete-blank-lines)
      (beginning-of-line)
      (comint-send-string (get-buffer-process (current-buffer)) "\n")
      (insert-string last-cmd)
      ;; return the shell output
      str)))

(defun lispy--eval-hy (str)
  "Eval STR as Hy code."
  (let ((res (lispy--comint-eval str)))
    (if (member res '("" "\n"))
        "(ok)"
      res)))

(defvar lispy-hy-link nil
  "global var to hold a link to open in `lispy_hy-describe'.")

(defun lispy--hy-describe (sym)
  "Describe sym with usage, doc and clickable link."
  (let* ((func (lispy--current-function))
         (map (make-sparse-keymap))
         (s (replace-regexp-in-string
             "\\\\\\n" "\n"
             (substring
              (lispy--eval-hy
               (format "(? \"%s\")" func)
               ;; (format "(let [flds (hylp-info \"%s\")]
               ;;      (.format \"Usage: {0}

               ;; {1}

               ;; [[{2}::{3}]]

               ;; \" (get flds 0) (get flds 1) (get flds 2) (get flds 3)))" sym)
               )
              2 -1))))

    (define-key map [mouse-1]
      (lambda ()
        (interactive)
        (org-open-link-from-string lispy-hy-link)))

    (string-match "\\[\\[.*\\]\\]" s)
    (setq lispy-hy-link (match-string 0 s))
    (set-text-properties (match-beginning 0)
                         (match-end 0)
                         `(local-map ,map
                                     mouse-face 'highlight
                                     help-echo "mouse-1: click me")
                         s)
    s))

(defun lispy--hy-args (sym)
  "Args for sym."
  (propertize
   (substring
    (lispy--eval-hy
     (format "(hyldoc \"%s\")" (lispy--current-function))
     ;; (format "(string
     ;; (try
     ;;  (get (hylp-info \"%s\") 0)
     ;;  (except [e Exception]
     ;;    \"\")))" sym)
     )
    2 -1)
   'font-lock-face '(:foreground "black" :background "Lightgoldenrod1")))


(defun lispy-goto-symbol-hy (&optional sym)
  "Jump to the SYM (if none is provided use `symbol-at-point'."
  (interactive (list (or (thing-at-point 'symbol t)
                         (lispy--current-function))))
  (org-open-link-from-string
   (substring
    (lispy--eval-hy (format
                     "(hyspy-file-lineno \"%s\")"
                     (or sym (symbol-at-point))))
    2 -1)))


(provide 'le-hy)

;;; le-hy.el ends here
