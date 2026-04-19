;;; Copyright © 2026 hirancph
;;;
;;; installer.scm — Minimal OS for building a custom installation ISO.
;;;
;;; This is NOT your daily-driver config.  It produces a bootable live
;;; ISO with the nonguix kernel and NVIDIA drivers pre-loaded so you
;;; can install Guix on NVIDIA hardware without network access to
;;; pull nonguix packages.
;;;
;;; Build with:
;;;   ./scripts/build-iso.sh

(define-module (edict systems installer)
  #:use-module (gnu)
  #:use-module (gnu system)
  #:use-module (gnu system install)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages vim)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu system linux-initrd))

(operating-system
  (inherit installation-os)
  (kernel linux)
  (firmware (list linux-firmware))
  (initrd microcode-initrd)

  (kernel-arguments
   (append '("modprobe.blacklist=nouveau"
             "nvidia_drm.modeset=1")
           %default-kernel-arguments))

  (packages
   (append (list git vim)
           (operating-system-packages installation-os))))
