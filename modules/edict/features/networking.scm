;;; Copyright © 2026 hirancph
;;;
;;; networking.scm — Network stack, Bluetooth, and time-sync feature.
;;;
;;; When a desktop-environment is active, %desktop-services already
;;; provides NetworkManager, wpa-supplicant, avahi, bluetooth, and NTP.
;;; This feature contributes only user groups and values.

(define-module (edict features networking)
  #:use-module (edict features)
  #:export (networking-feature))

(define* (networking-feature #:key
                             (bluetooth? #t))
  "Networking configuration: user groups for network and Bluetooth access.
Actual services are provided by %desktop-services when a desktop-environment
feature is active."

  ;; ── Validation ──
  (ensure-pred boolean? bluetooth?)

  (edict-feature
   #:name 'networking
   #:provides '(networking)
   #:requires '(base)
   #:values `((has-bluetooth? . ,bluetooth?))
   #:extensions
   (list
    (apply contribute user-groups-target
           (append '("netdev")
                   (if bluetooth? '("lp") '()))))))

