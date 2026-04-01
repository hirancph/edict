;;; Copyright © 2026 hirancph
;;;
;;; desktop.scm — Desktop session and seat management feature.
;;;
;;; Everything a graphical desktop needs before a window manager:
;;; login sessions, the system bus, authorisation, storage mounting,
;;; power info, font caching, and the X11 compatibility socket.

(define-module (edict features desktop)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services dbus)
  #:use-module (gnu services desktop)
  #:use-module (gnu services xorg)
  #:use-module (gnu system shadow)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages linux)
  #:use-module (edict features)
  #:export (desktop-feature))

(define* (desktop-feature #:key
                          (extra-user-groups '()))
  "Desktop session essentials: elogind, D-Bus, PolicyKit, udisks,
upower, fontconfig, XWayland socket, and brightness control."

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
                "gvfs" "brightnessctl")

    (contribute system-services-target
                (service elogind-service-type)
                (service dbus-root-service-type)
                (service polkit-service-type)
                polkit-wheel-service
                (service udisks-service-type)
                (service upower-service-type)
                fontconfig-file-system-service
                (service x11-socket-directory-service-type)
                (udev-rules-service 'brightnessctl-udev-rules brightnessctl)))))


