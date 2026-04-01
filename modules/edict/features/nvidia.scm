;;; Copyright © 2026 hirancph
;;;
;;; nvidia.scm — NVIDIA proprietary driver feature for Guix System.
;;;
;;; Note: We intentionally avoid nonguix-transformation-nvidia here.
;;; That transformation uses `replace-mesa` to graft the entire OS graphics
;;; stack. On a rolling release, if your Guix commit doesn't perfectly match
;;; Nonguix's CI server, it will force a from-source compilation of Mesa
;;; and 500+ graphical packages (taking 12+ hours and often failing).
;;; Instead, we use the stable, manual approach (identical to nehrbash's).

(define-module (edict features nvidia)
  #:use-module (gnu services)
  #:use-module (gnu services linux)
  #:use-module (gnu services shepherd)
  #:use-module (guix gexp)
  #:use-module (nongnu packages nvidia)
  #:use-module (nongnu services nvidia)
  #:use-module (edict features)
  #:export (nvidia-feature))

(define* (nvidia-feature #:key
                         (driver nvda)
                         (modesetting? #t)
                         (blacklist-nouveau? #t)
                         (preserve-video-memory? #t))
  "NVIDIA proprietary GPU driver setup.
Configures kernel args, loadable modules, and persistence mode without
globally grafting the OS to prevent source-compilation traps."

  ;; ── Validation ──
  (ensure-pred boolean? modesetting?)
  (ensure-pred boolean? blacklist-nouveau?)
  (ensure-pred boolean? preserve-video-memory?)

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
            (if modesetting? '("nvidia_drm.modeset=1") '())
            '("nvidia_modeset.vblank_sem_control=0")
            (if preserve-video-memory?
                '("nvidia.NVreg_PreserveVideoMemoryAllocations=1"
                  "nvidia.NVreg_TemporaryFilePath=/var/tmp")
                '())))

    (apply contribute system-services-target
           (append
            (list
             (service nvidia-service-type
                      (nvidia-configuration
                       (driver driver)))
             (service kernel-module-loader-service-type
                      '("nvidia"
                        "nvidia_modeset"
                        "nvidia_uvm"
                        "nvidia_drm")))

            ;; nvidia-smi persistence mode helps keep the GPU state
            ;; loaded across sleep/suspend boundaries.
            (if preserve-video-memory?
                (list
                 (simple-service 'nvidia-persistence
                                 shepherd-root-service-type
                                 (list (shepherd-service
                                        (provision '(nvidia-persistence))
                                        (requirement '(udev))
                                        (one-shot? #t)
                                        (start #~(lambda _
                                                   (zero? (system* #$(file-append driver "/bin/nvidia-smi")
                                                                   "-pm" "1"))))))))
                '()))))))

