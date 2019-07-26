;;; dockel.el --- description -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 'transient)
;; Customization options
(defgroup docker-group nil
  "Docker customization group"
  :group 'docker)

(defcustom docker-cmd "docker"
  "Docker executable name."
  :group 'docker-group
  :type 'string)

(defconst dockel--containers-format
  [("Id" 15 t)
   ("Status" 15 t)
   ("Image" 30 t)
   ("CreateAt" 20 t)
   ("Ports" 20 t)
   ("Names" 20 t)]
  "Containers format.")

;; Docker process function
(defun docker-run (action &optional args)
  "Run docker ACTION with optional ARGS."
  (shell-command-to-string
   (format "%s %s %s"
           docker-cmd
           action
           args)))

(defun docker-process ()
  "Start docker process."
  (interactive )
  (let ((process "*docker*")
        (buffer "*docker*"))
    (call-process "docker" nil buffer nil "container" "ls")
    (switch-to-buffer buffer)))
;;
;; Transient
;;
(define-infix-argument dockel--transient-logs:--tail ()
  :description "Tail"
  :class 'transient-option
  :key "=t"
  :argument "--tail=")

(define-infix-argument dockel--transient-logs:--since ()
  :description "Show logs since timestamp (e.g. 2013-01-02T13:23:37) or relative (e.g. 42m for 42 minutes)"
  :class 'transient-option
  :key "=s"
  :argument "--since=")

(define-infix-argument dockel--transient-logs:--until ()
  :description "Show logs until timestamp (e.g. 2013-01-02T13:23:37) or relative (e.g. 42m for 42 minutes)"
  :class 'transient-option
  :key "=u"
  :argument "--until=")

(define-transient-command dockel--transient-help-popup ()
  ["Containers actions:"
   ("l" "Log" dockel--transient-logs-pupup)
   ("i" "Inspect" dockel--transient-inspect-pupup)
   ])

(define-transient-command dockel--transient-logs-popup ()
  "Container logs."
  ["Arguments"
   ("-f" "Follow" "--follow")
   ("-t" "Show timestamps" "--timestamps")
   ("--details" "Show extra details provided to logs" "--details")
   (dockel--transient-logs:--tail)
   (dockel--transient-logs:--since)
   (dockel--transient-logs:--until)]
  ["Actions"
   ("l" "Log" dockel--cmd-container-logs)])

(define-transient-command dockel--transient-inspect-popup ()
  "Container logs."
  ["Actions"
   ("i" "Inspect" dockel--cmd-container-inspect)])

;; Docker container functions
; List
(defun dockel--cmd-container-ls ()
  "List of docker containers."
  (interactive)
  (let ((cmd-format "{{ .ID}}|{{.Status}}|{{.Image}}|{{.CreatedAt}}|{{.Ports}}|{{.Names}}"))
    (docker-run "container list" (format "--format=\"%s\"" cmd-format))))

; Logs
(defun dockel--cmd-container-logs (&optional args)
  "Get container logs with ARGS."
  (interactive
   (list (transient-args 'dockel--transient-logs-popup)))
  (let ((process "*docker*")
        (buffer "*docker-logs*")
        (container (aref (tabulated-list-get-entry) 0)))
    (if (member "-f" args)
        (apply #'start-process process buffer docker-cmd "container" "logs" container args)
      (apply #'call-process docker-cmd nil buffer nil "container" "logs" container args))
    (switch-to-buffer buffer)))

(defun dockel--cmd-container-inspect (&optional args)
  "Get container information with ARGS."
  (interactive
   (list (transient-args 'dockel--transient-inspect-popup)))
  (let ((buffer "*docker-inspect*")
        (container (aref (tabulated-list-get-entry) 0)))
    (apply #'call-process docker-cmd nil buffer nil "container" "inspect" container args)
    (with-current-buffer buffer
      (json-mode)
      (beginning-of-buffer)
      (switch-to-buffer buffer))))

;; Docker major mode
(defun dockel--containers-entries ()
  "Get containers entries for `tabulated-list-mode."
  (let (result)
    (dolist (line (split-string (dockel--cmd-container-ls) "\n") result)
      (when (> (length line) 1)
        (push (list nil (vconcat (split-string line "|"))) result)))))

(defun dockel--container-refresh ()
  "Refresh containers list."
  (setq tabulated-list-entries (dockel--containers-entries)))

(defvar dockel-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "?") 'dockel--transient-help-popup)
    (define-key map (kbd "l") 'dockel--transient-logs-popup)
    (define-key map (kbd "i") 'dockel--transient-inspect-popup)
    map)
  "Keymap for `dockel-mode'.")

;;; Remove -- this is testing
;; (makunbound 'dockel-mode-map)

(define-derived-mode dockel-mode tabulated-list-mode "Docker Containers"
  "Dockel mode for docker buffers."
  (buffer-disable-undo)
  (setq tabulated-list-format dockel--containers-format)
  (setq tabulated-list-entries 'dockel--containers-entries)
  (tabulated-list-init-header)
  (add-hook 'tabulated-list-revert-hook 'dockel--container-refresh nil t)
  (tablist-minor-mode)
  (hl-line-mode 1))

;;;###autoload
(defun dockel ()
  "List docket containers."
  (interactive)
  (switch-to-buffer "*dockel*")
  (dockel-mode)
  (tablist-revert))

(provide 'dockel)
;;; dockel.el ends here
