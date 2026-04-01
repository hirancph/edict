;;; Copyright © 2026 hirancph
;;;
;;; networking.scm — Network stack, Bluetooth, and time-sync feature.

(define-module (edict features networking)
  #:use-module (gnu services)
  #:use-module (gnu services avahi)
  #:use-module (gnu services desktop)
  #:use-module (gnu services networking)
  #:use-module (edict features)
  #:export (networking-feature))

(define* (networking-feature #:key
                             (bluetooth? #t)
                             (auto-enable-bluetooth? #t)
                             (ntp? #t)
                             (avahi? #t))
  "NetworkManager, Wi-Fi, Bluetooth, mDNS, and NTP.
Each sub-concern can be toggled off if not needed."

  ;; ── Validation ──
  (ensure-pred boolean? bluetooth?)
  (ensure-pred boolean? auto-enable-bluetooth?)
  (ensure-pred boolean? ntp?)
  (ensure-pred boolean? avahi?)

  (edict-feature
   #:name 'networking
   #:provides '(networking)
   #:requires '(base)
   #:values `((has-bluetooth? . ,bluetooth?)
              (has-avahi? . ,avahi?))
   #:extensions
   (list
    (apply contribute user-groups-target
           (append '("netdev")
                   (if bluetooth? '("lp") '())))

    (apply contribute system-services-target
           (append
            (list
             (service network-manager-service-type)
             (service wpa-supplicant-service-type))
            (if bluetooth?
                (list (service bluetooth-service-type
                               (bluetooth-configuration
                                (auto-enable? auto-enable-bluetooth?))))
                '())
            (if avahi?
                (list (service avahi-service-type))
                '())
            (if ntp?
                (list (service ntp-service-type))
                '()))))))


