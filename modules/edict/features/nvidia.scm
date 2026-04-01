;;; Copyright © 2026 hirancph
;;;
;;; nvidia.scm — NVIDIA proprietary driver feature for Guix System.
;;;
;;; Applies the official nonguix-transformation-nvidia which safely
;;; grafts the proprietary driver into mesa, configures the kernel arguments,
;;; and sets up the correct graphics services automatically.

(define-module (edict features nvidia)
  #:use-module (gnu services)
  #:use-module (nongnu packages nvidia)
  #:use-module (nongnu services nvidia)
  #:use-module (nonguix transformations)
  #:use-module (edict features)
  #:export (nvidia-feature))

(define* (nvidia-feature #:key
                         (driver nvidia-driver)
                         (modesetting? #t)
                         (s0ix-power-management? #t)
                         (configure-xorg? #t))
  "NVIDIA proprietary GPU driver.
Applies the official nonguix transformation for NVIDIA, grafting the
correct driver into all packages and configuring the display stack.
Publishes 'has-nvidia? so other features can adapt. System-scope only."

  ;; ── Validation ──
  (ensure-pred boolean? modesetting?)
  (ensure-pred boolean? s0ix-power-management?)
  (ensure-pred (lambda (x) (or (boolean? x) (symbol? x))) configure-xorg?)

  (edict-feature
   #:name 'nvidia
   #:provides '(nvidia gpu)
   #:requires '(nonguix base)
   #:scope 'system
   #:values `((has-nvidia? . #t)
              (nvidia-driver . ,driver))
   #:extensions
   (list
    (contribute user-groups-target "video")

    (contribute os-transformations-target
                (nonguix-transformation-nvidia #:driver driver
                                               #:kernel-mode-setting? modesetting?
                                               #:s0ix-power-management? s0ix-power-management?
                                               #:configure-xorg? configure-xorg?)))))
