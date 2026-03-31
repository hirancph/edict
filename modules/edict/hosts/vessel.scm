;;; Copyright © 2026 hirancph
;;;
;;; hosts/vessel.scm — Feature selection for the "vessel" host.
;;;
;;; This is the SINGLE SOURCE OF TRUTH for which features vessel uses.
;;; Both systems/vessel.scm and home/vessel.scm import from here,
;;; ensuring they always stay in sync.
;;;
;;; To customise vessel, edit the feature list below.
;;; To override a feature's defaults, pass keyword arguments:
;;;   (ssh-feature #:port 22 #:permit-root-login? #t)

(define-module (edict hosts vessel)
  #:use-module (edict features)
  #:use-module (edict features base)
  #:use-module (edict features desktop)
  #:use-module (edict features gnome)
  #:use-module (edict features gc)
  #:use-module (edict features networking)
  #:use-module (edict features nonguix)
  #:use-module (edict features nvidia)
  #:use-module (edict features ssh)
  #:export (%vessel-features
            %vessel))


;; ═══════════════════════════════════════════════════════════════════
;; Feature Selection — parameterized, composable, overridable
;; ═══════════════════════════════════════════════════════════════════
;;
;; Order does not matter — the feature engine topologically sorts
;; based on requires/provides declarations.

(define %vessel-features
  (list
   (nonguix-feature)            ;; non-free kernel + substitutes
   (nvidia-feature)             ;; NVIDIA proprietary GPU driver
   (desktop-feature)            ;; seat, D-Bus, PolicyKit, storage, power
   (gnome-feature)              ;; GNOME Desktop Environment
   (gc-feature)                 ;; Nightly garbage collection cron job
   (networking-feature)         ;; NetworkManager, Wi-Fi, Bluetooth, NTP
   (ssh-feature #:port 2222)    ;; OpenSSH daemon
   (base-feature)))             ;; core tools, symlinks, NTFS, cron GC


;; ═══════════════════════════════════════════════════════════════════
;; Composition
;; ═══════════════════════════════════════════════════════════════════

(define %vessel (compose-features %vessel-features))
