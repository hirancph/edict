;;; Copyright © 2026 hirancph
;;;
;;; nvidia.scm — NVIDIA proprietary driver feature for Guix System.
;;;
;;; Full RTX 3060 support: kernel args, loadable modules, persistence
;;; mode, VRAM preservation across suspend/resume, and sleep hooks.
;;; Modeled after nehrbash's proven RTX 3070 setup.

(define-module (edict features nvidia)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services linux)
  #:use-module (gnu services shepherd)
  #:use-module (guix gexp)
  #:use-module (nongnu packages nvidia)
  #:use-module (nongnu services nvidia)
  #:use-module (edict features)
  #:export (nvidia-feature))

(define* (nvidia-feature #:key
                         (driver nvidia-driver)
                         (modesetting? #t)
                         (blacklist-nouveau? #t)
                         (preserve-video-memory? #t))
  "NVIDIA proprietary GPU driver — kernel args, loadable modules,
persistence mode, VRAM preservation, and suspend/resume hooks.
Publishes 'has-nvidia? so other features (e.g. Hyprland, GNOME) can adapt.
System-scope only."

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
             (service nvidia-service-type)
             (service kernel-module-loader-service-type
                      '("nvidia"
                        "nvidia_modeset"
                        "nvidia_uvm"
                        "nvidia_drm")))

            ;; nvidia-smi persistence mode — keeps the driver loaded
            ;; so VRAM preservation actually works across suspend.
            (if preserve-video-memory?
                (list
                 (simple-service 'nvidia-persistence
                                 shepherd-root-service-type
                                 (list (shepherd-service
                                        (provision '(nvidia-persistence))
                                        (requirement '(udev))
                                        (one-shot? #t)
                                        (start #~(lambda _
                                                   (zero? (system* #$(file-append nvda "/bin/nvidia-smi")
                                                                   "-pm" "1"))))))))
                '()))))))
