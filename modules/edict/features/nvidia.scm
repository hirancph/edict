;;; Copyright © 2026 hirancph
;;;
;;; nvidia.scm — NVIDIA proprietary driver feature for Guix System.
;;;
;;; Matches nehrbash's proven RTX 3070 setup exactly:
;;; kernel args + nvidia-service-type + kernel module loader.

(define-module (edict features nvidia)
  #:use-module (gnu services)
  #:use-module (gnu services linux)
  #:use-module (nongnu packages nvidia)
  #:use-module (nongnu services nvidia)
  #:use-module (edict features)
  #:export (nvidia-feature))

(define* (nvidia-feature #:key
                         (modesetting? #t)
                         (blacklist-nouveau? #t))
  "NVIDIA proprietary GPU driver — kernel args, loadable modules, service.
Matches nehrbash's proven setup. System-scope only."

  ;; ── Validation ──
  (ensure-pred boolean? modesetting?)
  (ensure-pred boolean? blacklist-nouveau?)

  (edict-feature
   #:name 'nvidia
   #:provides '(nvidia gpu)
   #:requires '(nonguix base)
   #:scope 'system
   #:values `((has-nvidia? . #t))
   #:extensions
   (list
    (contribute user-groups-target "video")

    (apply contribute kernel-arguments-target
           (append
            (if blacklist-nouveau?
                '("modprobe.blacklist=nouveau") '())
            (if modesetting?
                '("nvidia_drm.modeset=1") '())
            '("nvidia_modeset.vblank_sem_control=0")))

    (contribute system-services-target
     (service nvidia-service-type)
     (service kernel-module-loader-service-type
              '("nvidia"
                "nvidia_modeset"
                "nvidia_uvm"
                "nvidia_drm"))))))


