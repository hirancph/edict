;;; Copyright © 2026 hirancph
;;;
;;; nonguix.scm — Non-free kernel and substitute server configuration.
;;;
;;; The kernel, firmware, and initrd are published as values so that
;;; the build module can automatically wire them into operating-system.
;;; This is a system-only feature — it has no effect on home-environment.

(define-module (edict features nonguix)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (guix gexp)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu system linux-initrd)
  #:use-module (edict features)
  #:export (nonguix-feature))

(define* (nonguix-feature #:key
                          (kernel linux)
                          (firmware (list linux-firmware))
                          (initrd microcode-initrd))
  "Non-free kernel, firmware, initrd, and substitute server.
Publishes kernel/firmware/initrd as values so the build module can
wire them in automatically.  System-scope only."

  ;; ── Validation ──
  (ensure-pred list? firmware)

  (edict-feature
   #:name 'nonguix
   #:provides '(nonguix kernel)
   #:requires '()
   #:scope 'system
   #:values (make-feature-values kernel firmware initrd)
   #:extensions
   (list
    (contribute system-services-target
     (simple-service 'add-nonguix-substitutes
                     guix-service-type
                     (guix-extension
                      (substitute-urls
                       (append %default-substitute-urls
                               '("https://substitutes.nonguix.org")))
                      (authorized-keys
                       (append (list (plain-file "nonguix.pub"
                                      "(public-key (ecc (curve Ed25519) (q #C1FD53E5D4CE971933EC50C9F307AE2171A2D3B52C804642A7A35F84F3A4EA98#)))"))
                               %default-authorized-guix-keys))))))))

