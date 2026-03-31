;;; Copyright © 2026 hirancph
;;;
;;; gnome.scm — GNOME Desktop Environment feature.

(define-module (edict features gnome)
  #:use-module (gnu services)
  #:use-module (gnu services desktop)
  #:use-module (gnu services xorg)
  #:use-module (edict features)
  #:export (gnome-feature))

(define* (gnome-feature #:key
                        (wayland? #f)
                        (auto-suspend? #f))
  "GNOME Desktop Environment with GDM.
WAYLAND? — enable Wayland in GDM (default: #f for VM compatibility).
AUTO-SUSPEND? — let GNOME auto-suspend the machine (default: #f)."

  ;; ── Validation ──
  (ensure-pred boolean? wayland?)
  (ensure-pred boolean? auto-suspend?)

  (edict-feature
   #:name 'gnome
   #:provides '(gnome desktop-environment)
   #:requires '(desktop networking)
   #:extensions
   (list
    (contribute system-services-target
                (service gnome-desktop-service-type)
                (service gdm-service-type
                         (gdm-configuration
                          (wayland? wayland?)
                          (auto-suspend? auto-suspend?)))))))
