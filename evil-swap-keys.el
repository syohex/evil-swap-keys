;;; evil-swap-keys.el --- intelligently swap keys on text input with evil -*- lexical-binding: t; -*-

;; Author: Wouter Bolsterlee <wouter@bolsterl.ee>
;; Version: 1.0.0
;; Package-Requires: ((emacs "24") (evil "1.2.12"))
;; Keywords: evil key swap numbers symbols
;; URL: https://github.com/wbolster/evil-swap-keys
;;
;; This file is not part of GNU Emacs.

;;; License:

;; Licensed under the same terms as Emacs.

;;; Commentary:

;; Minor mode to intelligently swap keys when entering text.
;; See the README for more details.

;;; Code:

(require 'evil)

(defgroup evil-swap-keys nil
  "Intelligently swap keys when entering text"
  :prefix "evil-swap-keys-"
  :group 'evil)

(defcustom evil-swap-keys-number-row-keys
  '(("1" . "!")
    ("2" . "@")
    ("3" . "#")
    ("4" . "$")
    ("5" . "%")
    ("6" . "^")
    ("7" . "&")
    ("8" . "*")
    ("9" . "(")
    ("0" . ")"))
  "The numbers and symbols on the keyboard's number row.

This should match the actual keyboard layout."
  :group 'evil-swap-keys
  :type '(alist
          :key-type string
          :value-type string))

(defcustom evil-swap-keys-number-row-swapped t
  "Whether to swap the keys on the number row.

Disable this if the keyboard layout already uses symbols by default
for the number row, e.g. French AZERTY keyboards."
  :group 'evil-swap-keys
  :type 'boolean)
(make-variable-buffer-local 'evil-swap-keys-number-row-swapped)

(defcustom evil-swap-keys-text-input-states
  '(emacs
    insert
    replace)
  "Evil states in which key presses will be treated as text input."
  :group 'evil-swap-keys
  :type '(repeat symbol))

(defcustom evil-swap-keys-text-input-commands
  '(evil-find-char
    evil-find-char-backward
    evil-find-char-to
    evil-find-char-to-backward
    evil-replace
    evil-snipe-f
    evil-snipe-F
    evil-snipe-s
    evil-snipe-S
    evil-snipe-t
    evil-snipe-T
    evil-snipe-x
    evil-snipe-X)
  "Commands that read keys which should be treated as text input."
  :group 'evil-swap-keys
  :type '(repeat function))

(defvar evil-swap-keys--active-mappings nil
  "Active mappings for this buffer.")
(make-variable-buffer-local 'evil-swap-keys--active-mappings)

(defvar evil-swap-keys--extra-mappings nil
  "Extra key mappings in addition to the number row.")
(make-variable-buffer-local 'evil-swap-keys--extra-mappings)

(defun evil-swap-keys--text-input-p ()
  "Determine whether the current input should treated as text input."
  ;; NOTE: The evil-this-type check is a hack that seems to work well
  ;; for motions. This variable is non-nil while reading motions
  ;; themselves, but not while entering a (optional) count prefix for
  ;; those motions. This makes things like d2t@ (delete until the
  ;; second @ sign) work without using the shift key at all: the first
  ;; 2 is a count and will not be translated, and the second 2 will be
  ;; translated into a @ since the 't' motion reads text input.
  (or
   evil-this-type
   (memq evil-state evil-swap-keys-text-input-states)
   (memq this-command evil-swap-keys-text-input-commands)))

(defun evil-swap-keys--maybe-translate (&optional prompt)
  "Maybe translate the current input.

The PROMPT argument is ignored; it's only there for compatibility with
the 'key-translation-map callback signature."
  (let ((key (string last-input-event)))
    (when (and evil-swap-keys--active-mappings
               evil-local-mode
               (evil-swap-keys--text-input-p))
      (let ((mapping (assoc key evil-swap-keys--active-mappings)))
        (when mapping
          (setq key (cdr mapping)))))
    key))

(defun evil-swap-keys--enable ()
  "Enable key swapping in this buffer."
  (evil-swap-keys--add-bindings))

(defun evil-swap-keys--disable ()
  "Disable key swapping in this buffer."
  ;; This does not remove any bindings, since other buffers may also
  ;; need those bindings.
  (setq evil-swap-keys--active-mappings nil))

(defun evil-swap-keys--add-bindings ()
  "Add bindings to the global 'key-translation-map'."
  (setq evil-swap-keys--active-mappings nil)
  (when evil-swap-keys-number-row-swapped
    (dolist (pair evil-swap-keys-number-row-keys)
      (let ((from (car pair))
            (to (cdr pair)))
        (add-to-list 'evil-swap-keys--active-mappings (cons from to))
        (add-to-list 'evil-swap-keys--active-mappings (cons to from)))))
  (dolist (mapping evil-swap-keys--extra-mappings)
    (let ((from (car mapping))
          (to (cdr mapping)))
      (add-to-list 'evil-swap-keys--active-mappings (cons from to))))
  (dolist (mapping evil-swap-keys--active-mappings)
    (let ((key (car mapping)))
      ;; Note: key-translation-map is global. The callback uses the
      ;; local configuration to decide whether the key should be
      ;; translated.
      (define-key key-translation-map
        key #'evil-swap-keys--maybe-translate))))

(defun evil-swap-keys--remove-bindings ()
  "Remove bindings from the global 'key-translation-map'."
  (dolist (key (where-is-internal #'evil-swap-keys--maybe-translate
                                  key-translation-map))
    (define-key key-translation-map key nil)))

;;;###autoload
(define-minor-mode evil-swap-keys-mode
  "Minor mode to intelligently swap keyboard keys during text input."
  :group 'evil-swap-keys
  :lighter " !1"
  (if evil-swap-keys-mode
      (evil-swap-keys--enable)
    (evil-swap-keys--disable)))

;;;###autoload
(define-globalized-minor-mode global-evil-swap-keys-mode
  evil-swap-keys-mode
  (lambda () (evil-swap-keys-mode t))
  "Global minor mode to intelligently swap keyboard keys during text input.")

;;;###autoload
(defun evil-swap-keys-add-mapping (from to)
  "Add a one-way mapping from key FROM to key TO."
  (add-to-list 'evil-swap-keys--extra-mappings (cons from to))
  (evil-swap-keys--add-bindings))

;;;###autoload
(defun evil-swap-keys-add-pair (a b)
  "Add a two-way mapping to swap keys A and B."
  (evil-swap-keys-add-mapping a b)
  (evil-swap-keys-add-mapping b a))

;;;###autoload
(defun evil-swap-keys-swap-underscore-dash ()
  "Swap the underscore and the dash."
  (evil-swap-keys-add-pair "_" "-"))

;;;###autoload
(defun evil-swap-keys-swap-colon-semicolon ()
  "Swap the colon and semicolon."
  (evil-swap-keys-add-pair ":" ";"))

;;;###autoload
(defun evil-swap-keys-swap-tilde-backtick ()
  "Swap the backtick and tilde."
  (evil-swap-keys-add-pair "~" "`"))

;;;###autoload
(defun evil-swap-keys-swap-double-single-quotes ()
  "Swap the double and single quotes."
  (evil-swap-keys-add-pair "\"" "'"))

;;;###autoload
(defun evil-swap-keys-swap-square-curly-brackets ()
  "Swap the square and curly brackets."
  (evil-swap-keys-add-pair "[" "{")
  (evil-swap-keys-add-pair "]" "}"))

;;;###autoload
(defun evil-swap-keys-swap-pipe-backslash ()
  "Swap the pipe and backslash."
  (evil-swap-keys-add-pair "|" "\\"))

;;;###autoload
(defun evil-swap-keys-swap-question-mark-slash ()
  "Swap the question mark and slash."
  (evil-swap-keys-add-pair "/" "?"))

;; TODO: minibuffer text entry. (active-minibuffer-window) perhaps?

(provide 'evil-swap-keys)
;;; evil-swap-keys.el ends here
