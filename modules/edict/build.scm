;;; Copyright © 2026 hirancph
;;;
;;; build.scm — Auto-generate operating-system and home-environment
;;; from composed features.
;;;
;;; The builders extract all feature-contributed extensions (packages,
;;; services, kernel args, etc.) and splice them into the final Guix
;;; records.  Machine-specific fields (bootloader, file-systems) are
;;; provided as trailing fields and take precedence.
;;;
;;; Usage:
;;;
;;;   (edict-operating-system %config
;;;     (host-name "vessel")
;;;     (bootloader (bootloader-configuration ...))
;;;     (file-systems (list ...)))

(define-module (edict build)
  #:use-module (gnu)
  #:use-module (gnu system)
  #:use-module (gnu system nss)
  #:use-module (gnu home)
  #:use-module (gnu home services)
  #:use-module (srfi srfi-1)
  #:use-module (edict config)
  #:use-module (edict features)
  #:export (edict-operating-system
            edict-home-environment))


;; ═══════════════════════════════════════════════════════════════════
;; Operating System Builder
;; ═══════════════════════════════════════════════════════════════════
;;
;; This macro generates a complete operating-system record from a
;; composed-features record.  It auto-wires:
;;   - kernel, firmware, initrd   (from feature values, if present)
;;   - kernel-arguments           (from kernel-arguments-target)
;;   - kernel-loadable-modules    (from kernel-modules-target)
;;   - users                      (from user-accounts-target, or default)
;;   - groups                     (from groups-target)
;;   - packages                   (from system-packages-target)
;;   - services                   (from system-services-target)
;;
;; Machine-specific fields (bootloader, file-systems, host-name, etc.)
;; come last and override the auto-wired values.

(define-syntax edict-operating-system
  (syntax-rules ()
    "Build an operating-system from a composed-features record.
Kernel/firmware/initrd are automatically pulled from feature values.
Only bootloader and file-systems are required as machine-specific."
    ((_ composed-expr field ...)
     (let* ((composed composed-expr)
            (kern (get-value 'kernel composed #f))
            (fw   (get-value 'firmware composed #f))
            (ird  (get-value 'initrd composed #f))
            (extra-accounts (get-extensions composed user-accounts-target)))
       (operating-system
         ;; Kernel — auto-wired from feature values when present
         (kernel (or kern linux))
         (firmware (or fw '()))
         (initrd (or ird (@ (gnu system linux-initrd) base-initrd)))

         ;; Auto-wired from composed features:
         (kernel-arguments
          (append (get-extensions composed kernel-arguments-target)
                  %default-kernel-arguments))
         (kernel-loadable-modules
          (get-extensions composed kernel-modules-target))

         ;; User accounts — default user + any feature-contributed accounts
         (users
          (append
           (list (user-account
                  (name %user-name)
                  (comment %full-name)
                  (group "users")
                  (home-directory (string-append "/home/" %user-name))
                  (supplementary-groups
                   (delete-duplicates
                    (get-extensions composed user-groups-target)
                    string=?))))
           extra-accounts
           %base-user-accounts))

         (groups
          (append (get-extensions composed groups-target) %base-groups))
         (packages
          (append (get-extensions composed system-packages-target)
                  %base-packages))
         (services
          (append %base-services
                  (get-extensions composed system-services-target)))
         (name-service-switch %mdns-host-lookup-nss)

         ;; Machine-specific overrides come last and win:
         field ...)))))


;; ═══════════════════════════════════════════════════════════════════
;; Home Environment Builder
;; ═══════════════════════════════════════════════════════════════════
;;
;; Generates a home-environment from composed features.
;; Only home-packages-target and home-services-target are extracted.
;; Additional per-host fields can be spliced in as trailing fields.

(define-syntax edict-home-environment
  (syntax-rules ()
    "Build a home-environment from a composed-features record.
Trailing FIELD forms are spliced directly into the home-environment."
    ((_ composed-expr field ...)
     (let ((composed composed-expr))
       (home-environment
         (packages (get-extensions composed home-packages-target))
         (services (get-extensions composed home-services-target))
         field ...)))))
