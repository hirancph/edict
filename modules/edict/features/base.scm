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
  #:use-module (edict config)
  #:export (base-feature))

(define* (base-feature #:key
                       (extra-packages '())
                       (extra-user-groups '())
                       (quiet-boot? #t)
                       (fhs-compat? #t))
  "Essential system tools, FHS symlinks, and boot configuration.
QUIET-BOOT? — suppress kernel console messages for a clean boot.
FHS-COMPAT? — add /lib64 ld-linux shim for foreign binaries."

  ;; ── Validation ──
  (ensure-pred list? extra-packages)
  (ensure-pred list? extra-user-groups)
  (ensure-pred boolean? quiet-boot?)
  (ensure-pred boolean? fhs-compat?)

  (edict-feature
   #:name 'base
   #:provides '(base)
   #:requires '()
   #:extensions
   (list
    (apply contribute user-groups-target
           (append '("wheel" "kvm") extra-user-groups))

    (apply contribute system-packages-target
           (append (list "git" "vim" "make"
                         "ntfs-3g" "exfat-utils" "fuse-exfat")
                   extra-packages))

    (apply contribute kernel-arguments-target
           (if quiet-boot?
               '("quiet" "loglevel=3")
               '()))

    (apply contribute system-services-target
           (append
            (list
             ;; FHS compatibility symlinks
             (simple-service 'fhs-symlinks
                             special-files-service-type
                             (append
                              `(("/bin/bash"    ,(file-append bash "/bin/bash"))
                                ("/usr/bin/env" ,(file-append coreutils "/bin/env")))
                              ;; /lib64 shim for foreign binaries (Bun SFEs, etc.)
                              (if fhs-compat?
                                  `(("/lib64/ld-linux-x86-64.so.2"
                                     ,(file-append glibc "/lib/ld-linux-x86-64.so.2")))
                                  '())))

             ;; NTFS udev rules for non-root mounting
             (simple-service 'ntfs-mount-rules udev-service-type (list ntfs-3g)))

            ;; D-Bus connection limit increase — prevents "too many connections"
            ;; when multiple session services (portals, polkit, keyring) are active.
            (list
             (extra-special-file "/etc/dbus-1/system.d/increase-limits.conf"
              (plain-file "increase-limits.conf"
               "<busconfig>\n  <limit name=\"max_connections_per_user\">1024</limit>\n</busconfig>\n"))))))))
