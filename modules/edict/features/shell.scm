;;; Copyright © 2026 hirancph
;;;
;;; shell.scm — Shell configuration feature (home-scoped).
;;;
;;; Provides Zsh configuration as a home service, including
;;; environment variables, aliases, and useful plugins.

(define-module (edict features shell)
  #:use-module (gnu home services)
  #:use-module (gnu home services shells)
  #:use-module (gnu packages shellutils)
  #:use-module (guix gexp)
  #:use-module (edict features)
  #:use-module (edict config)
  #:export (shell-feature))

(define* (shell-feature #:key
                        (editor "vim")
                        (extra-env-vars '())
                        (extra-aliases '())
                        (extra-path '("$HOME/.local/bin")))
  "Shell configuration — Zsh with plugins and environment variables.
Contributes to the home environment only.
EXTRA-PATH — additional directories prepended to $PATH."

  ;; ── Validation ──
  (ensure-pred string? editor)
  (ensure-pred list? extra-env-vars)
  (ensure-pred list? extra-aliases)
  (ensure-pred list? extra-path)

  (edict-feature
   #:name 'shell
   #:provides '(shell)
   #:requires '(base)
   #:scope 'home
   #:extensions
   (list
    (contribute home-packages-target
                "zsh" "zsh-autosuggestions" "zsh-syntax-highlighting"
                "zsh-autopair" "zsh-history-substring-search" "fzf-tab")

    (contribute home-services-target
     ;; Environment variables
     (simple-service 'edict-env-vars
                     home-environment-variables-service-type
                     (append
                      `(("EDITOR" . ,editor)
                        ("VISUAL" . ,editor)
                        ("TERM" . "xterm-256color")
                        ;; Dev tool paths — XDG-compliant
                        ("GOPATH" . "$HOME/.local/share/go")
                        ("NPM_CONFIG_PREFIX" . "$HOME/.local/share/npm")
                        ;; SSH agent socket (works when ssh-agent is running)
                        ("SSH_AUTH_SOCK" . "$XDG_RUNTIME_DIR/ssh-agent.socket")
                        ;; PATH extensions
                        ("PATH" . ,(string-append
                                    "$PATH:"
                                    (string-join extra-path ":"))))
                      extra-env-vars))

     ;; Zsh configuration
     (service home-zsh-service-type
              (home-zsh-configuration
               (zshenv
                (list (plain-file "zshenv" "setopt NULL_GLOB\n")))
               (zshrc
                (list
                 (mixed-text-file "zsh-plugins"
                  "source " zsh-autosuggestions
                  "/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh\n"
                  "source " zsh-autopair
                  "/share/zsh/plugins/zsh-autopair/zsh-autopair.zsh\n"
                  "source " zsh-history-substring-search
                  "/share/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh\n"
                  ;; syntax-highlighting must be sourced last
                  "source " zsh-syntax-highlighting
                  "/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh\n")
                 (plain-file "zshrc-aliases"
                  (string-append
                   "# Aliases\n"
                   "alias ls='ls --color=auto'\n"
                   "alias ll='ls -lah'\n"
                   "alias gs='git status'\n"
                   "alias gd='git diff'\n"
                   (string-join
                    (map (lambda (pair)
                           (string-append "alias "
                                          (car pair) "='"
                                          (cdr pair) "'"))
                         extra-aliases)
                    "\n"
                    'suffix)))
                 ;; fzf-tab must load after compinit (which runs in zshrc)
                 (mixed-text-file "zsh-fzf-tab"
                  "source " fzf-tab
                  "/share/zsh/plugins/fzf-tab/fzf-tab.zsh\n")))))))))
