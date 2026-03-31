;;; Copyright © 2026 hirancph
;;;
;;; base.scm — Essential tools, compatibility shims, and maintenance.
;;;
;;; The "batteries included" feature that every edict host should use.
;;; Provides: FHS symlinks, NTFS/exFAT support, and core CLI tools.

(define-module (edict features base)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages linux)
  #:use-module (guix gexp)
  #:use-module (edict features)
  #:export (base-feature))

(define* (base-feature #:key
                       (extra-packages '())
                       (extra-user-groups '()))
  "Essential system tools and FHS symlinks."

  ;; ── Validation ──
  (ensure-pred list? extra-packages)
  (ensure-pred list? extra-user-groups)

  (edict-feature
   #:name 'base
   #:provides '(base)
   #:requires '()
   #:extensions
   (list
    (apply contribute user-groups-target
           (append '("wheel" "kvm") extra-user-groups))

    (apply contribute system-packages-target
           (append (list "git" "vim" "make" "ntfs-3g" "exfat-utils" "fuse-exfat")
                   extra-packages))

    (contribute system-services-target
     ;; FHS compatibility symlinks
     (simple-service 'fhs-symlinks
                     special-files-service-type
                     `(("/bin/bash"    ,(file-append bash "/bin/bash"))
                       ("/usr/bin/env" ,(file-append coreutils "/bin/env"))))

     ;; NTFS udev rules for non-root mounting
     (simple-service 'ntfs-mount-rules udev-service-type (list ntfs-3g))))))
