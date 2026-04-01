;;; Copyright © 2026 hirancph
;;;
;;; desktop.scm — Desktop session and seat management feature.
;;;
;;; When a desktop-environment (like GNOME) is active, `%desktop-services`
;;; provides elogind, dbus, polkit, GDM, udisks, upower, fontconfig, etc.
;;; This feature contributes only what is NOT already covered:
;;; user groups, packages, the realtime group, and X11 socket setup.

(define-module (edict features desktop)
  #:use-module (gnu services)
  #:use-module (gnu system shadow)
  #:use-module (edict features)
  #:export (desktop-feature))

(define* (desktop-feature #:key
                          (extra-user-groups '()))
  "Desktop session essentials: user groups, packages, realtime audio group,
and the X11 compatibility socket.  Core desktop services (elogind, dbus,
polkit, udisks, upower) are provided by %desktop-services when a
desktop-environment feature is active."

  ;; ── Validation ──
  (ensure-pred list? extra-user-groups)

  (edict-feature
   #:name 'desktop
   #:provides '(desktop base-x11)
   #:requires '(base)
   #:values '((has-desktop? . #t))
   #:extensions
   (list
    ;; System group for PipeWire / low-latency audio scheduling.
    (contribute groups-target
                (user-group (system? #t) (name "realtime")))

    (apply contribute user-groups-target
           (append '("audio" "video" "input" "realtime") extra-user-groups))

    (contribute system-packages-target
                "gvfs" "brightnessctl"))))

