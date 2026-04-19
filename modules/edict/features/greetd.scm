;;; Copyright © 2026 hirancph
;;;
;;; greetd.scm — greetd + tuigreet login manager feature.
;;;
;;; Replaces GDM/mingetty with greetd on VT1 running tuigreet.
;;; tuigreet discovers available sessions from the wayland-sessions
;;; directory and remembers the last selection.

(define-module (edict features greetd)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services xorg)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages wm)
  #:use-module (guix gexp)
  #:use-module (edict features)
  #:export (greetd-feature))

(define* (greetd-feature #:key
                         (remember-session? #t)
                         (show-time? #t))
  "greetd login manager with tuigreet on VT1.
Provides a clean TUI login that discovers Wayland sessions
(like Hyprland) from the system profile."

  ;; ── Validation ──
  (ensure-pred boolean? remember-session?)
  (ensure-pred boolean? show-time?)

  (edict-feature
   #:name 'greetd
   #:provides '(greetd login-manager)
   #:requires '(desktop)
   #:scope 'system
   #:extensions
   (list
    ;; tuigreet must be in system packages so greetd can execute it.
    (contribute system-packages-target
                "greetd" "greetd-tuigreet")

    (contribute system-services-target
     (service greetd-service-type
              (greetd-configuration
               (greeter-supplementary-groups '("video" "input"))
               (terminals
                (list
                 ;; VT1: graphical greeter
                 (greetd-terminal-configuration
                  (terminal-vt "1")
                  (terminal-switch #t)
                  (default-session-command
                    (greetd-user-session
                     (command (file-append tuigreet "/bin/tuigreet"))
                     (command-args
                      (append
                       (if show-time? '("--time") '())
                       (if remember-session?
                           '("--remember" "--remember-session")
                           '())
                       '("--sessions"
                         "/run/current-system/profile/share/wayland-sessions")))))))))))

    ;; Remove GDM from %desktop-services if it's present.
    ;; This is done as an OS transformation so it runs after
    ;; the base services are merged.
    (contribute os-transformations-target
     (lambda (os)
       (operating-system
         (inherit os)
         (services
          (remove (lambda (s)
                    (or (eq? (service-kind s) gdm-service-type)
                        ;; Also remove mingetty on VT1 since greetd owns it
                        (and (eq? (service-kind s) mingetty-service-type)
                             (string=? "tty1"
                                       (mingetty-configuration-tty
                                        (service-value s))))))
                  (operating-system-user-services os)))))))))
