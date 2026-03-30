;;; Copyright © 2026 hirancph
;;;
;;; base.scm — Essential tools, compatibility shims, and maintenance.
;;;
;;; The "batteries included" feature that every edict host should use.
;;; Provides: FHS symlinks, NTFS/exFAT support, nightly garbage
;;; collection, and core CLI tools.

(define-module (edict features base)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services mcron)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages certs)
  #:use-module (gnu packages file-systems)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages vim)
  #:use-module (guix gexp)
  #:use-module (edict features)
  #:export (base-feature))

(define* (base-feature #:key
                       (gc-days 30)
                       (gc-free "5G")
                       (extra-packages '())
                       (extra-user-groups '()))
  "Essential system tools, FHS symlinks, and nightly GC.
GC-DAYS: delete generations older than this.  GC-FREE: minimum free space."

  ;; ── Validation ──
  (ensure-pred integer? gc-days)
  (ensure-pred string? gc-free)
  (ensure-pred list? extra-packages)
  (ensure-pred list? extra-user-groups)

  (edict-feature
   #:name 'base
   #:provides '(base)
   #:requires '()
   #:values `((gc-days . ,gc-days)
              (gc-free . ,gc-free))
   #:extensions
   (list
    (apply contribute user-groups-target
           (append '("wheel" "kvm") extra-user-groups))

    (apply contribute system-packages-target
           (append (list git vim nss-certs ntfs-3g exfat-utils fuse-exfat)
                   extra-packages))

    (contribute system-services-target
     ;; FHS compatibility symlinks
     (service special-files-service-type
              `(("/bin/bash"    ,(file-append bash "/bin/bash"))
                ("/usr/bin/env" ,(file-append coreutils "/bin/env"))))

     ;; NTFS udev rules for non-root mounting
     (simple-service 'ntfs-mount-rules udev-service-type (list ntfs-3g))

     ;; Nightly GC
     (simple-service 'system-cron-jobs
                     mcron-service-type
                     (list
                      #~(job "5 0 * * *"
                             (string-append
                              "guix gc -d "
                              #$(number->string gc-days)
                              "d -F "
                              #$gc-free))))))))
