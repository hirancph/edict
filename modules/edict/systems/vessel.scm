;;; Copyright © 2026 hirancph
;;;
;;; systems/vessel.scm — Operating system declaration for "vessel".
;;;
;;; This file is beautifully minimal.  All reusable logic lives in
;;; feature modules, and the feature list is defined once in
;;; (edict hosts vessel).  This file declares ONLY what is unique to
;;; this machine's hardware: bootloader and file systems.
;;;
;;; Apply with:
;;;   make system

(define-module (edict systems vessel)
  #:use-module (gnu)
  #:use-module (edict config)
  #:use-module (edict features)
  #:use-module (edict build)
  #:use-module (edict hosts vessel))


;; ═══════════════════════════════════════════════════════════════════
;; Operating System — only machine-specific hardware below
;; ═══════════════════════════════════════════════════════════════════
;;
;; Kernel, firmware, and initrd are automatically wired from the
;; nonguix feature's values.  No need to extract them manually.

(edict-operating-system %vessel

  (host-name "vessel")
  (timezone  %timezone)
  (locale    %locale)
  (keyboard-layout (keyboard-layout "us"))

  ;; Bootloader — UEFI GRUB, dual-boot with Windows
  (bootloader
   (bootloader-configuration
    (bootloader grub-efi-bootloader)
    (targets '("/boot/efi"))
    (keyboard-layout (keyboard-layout "us"))))

  ;; File systems — vessel hardware
  (file-systems
   (cons*
    (file-system
     (device (uuid "726825b4-7c05-4909-81d2-abdd71548019" 'ext4))
     (mount-point "/")
     (type "ext4"))
    (file-system
     (device (uuid "3DA9-349D" 'fat32))
     (mount-point "/boot/efi")
     (type "vfat"))
    %base-file-systems)))
