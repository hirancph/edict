;;; Copyright © 2026 hirancph
;;;
;;; gnome.scm — GNOME Desktop Environment feature.
;;;
;;; Signals `build.scm` to use `%desktop-services` (which includes GDM)
;;; instead of `%base-services`.  Contributes `gnome-desktop-service-type`
;;; for the GNOME session integration.

(define-module (edict features gnome)
  #:use-module (gnu services)
  #:use-module (gnu services desktop)
  #:use-module (gnu services xorg)
  #:use-module (edict features)
  #:export (gnome-feature))

(define* (gnome-feature)
  "GNOME Desktop Environment.
Sets has-desktop-environment? so build.scm uses %desktop-services
(which already provides GDM, elogind, dbus, polkit, etc.).
Contributes gnome-desktop-service-type for GNOME session integration."

  (edict-feature
   #:name 'gnome
   #:provides '(gnome desktop-environment)
   #:requires '(desktop networking)
   #:values '((has-desktop-environment? . #t))
   #:extensions
   (list
    (contribute system-services-target
                (service gnome-desktop-service-type)))))

