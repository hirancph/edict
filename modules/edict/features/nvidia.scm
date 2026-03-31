;;; Copyright © 2026 hirancph
;;;
;;; nvidia.scm — NVIDIA proprietary driver feature for Guix System.
;;;
;;; System-scope only — contributes kernel arguments, loadable modules,
;;; and services for the NVIDIA proprietary driver.

(define-module (edict features nvidia)
  #:use-module (gnu services)
  #:use-module (gnu services linux)
  #:use-module (nongnu packages nvidia)
  #:use-module (nongnu services nvidia)
  #:use-module (edict features)
  #:export (nvidia-feature))

(define* (nvidia-feature #:key
                         (driver nvidia-driver)
                         (modesetting? #t)
                         (blacklist-nouveau? #t))
  "NVIDIA proprietary GPU driver — kernel args, loadable modules, services.
Publishes 'has-nvidia? so other features (e.g. Hyprland) can adapt.
System-scope only."

  ;; ── Validation ──
  (ensure-pred boolean? modesetting?)
  (ensure-pred boolean? blacklist-nouveau?)

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

    (apply contribute kernel-arguments-target
           (append
            (if blacklist-nouveau? '("modprobe.blacklist=nouveau") '())
            (if modesetting? '("nvidia_drm.modeset=1") '())))

    (contribute system-services-target
     (service nvidia-service-type)
     (service kernel-module-loader-service-type
              '("nvidia"
                "nvidia_modeset"
                "nvidia_uvm"
                "nvidia_drm"))))))
