;;; Copyright © 2026 hirancph
;;;
;;; gnome.scm — GNOME Desktop Environment feature.

(define-module (edict features gnome)
  #:use-module (gnu services)
  #:use-module (gnu services desktop)
  #:use-module (gnu services xorg)
  #:use-module (edict features)
  #:export (gnome-feature))

(define* (gnome-feature)
  "GNOME Desktop Environment with GDM."
  (edict-feature
   #:name 'gnome
   #:provides '(gnome desktop-environment)
   #:requires '(desktop networking)
   #:extensions
   (list
    (contribute system-services-target
                (service gnome-desktop-service-type)
                (service gdm-service-type)))))
