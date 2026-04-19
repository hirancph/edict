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
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu system)
  #:use-module (gnu system nss)
  #:use-module (gnu services desktop)
  #:use-module (gnu packages)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages shells)
  #:use-module (gnu home)
  #:use-module (gnu home services)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:use-module (edict config)
  #:use-module (edict features)
  #:export (edict-operating-system
            edict-home-environment))

;; ═══════════════════════════════════════════════════════════════════
;; Shared Helpers
;; ═══════════════════════════════════════════════════════════════════

(define (resolve-package p)
  "Convert strings to packages if needed, otherwise return the package."
  (if (string? p)
      (specification->package p)
      p))

(define (merge-services base-services feature-services)
  "Merge base and feature services gracefully.
If feature-services provides a service of a specific type, it overrides
the base service of that type.
If multiple features provide the same service kind, they are merged if
identical or default, otherwise an explicit error is raised.
Exception: mingetty-service-type is preserved since it must exist multiple times."
  (define (deduplicate-services services)
    (fold (lambda (new-svc acc)
            (let ((dup-svc (find (lambda (s) 
                                   (and (eq? (service-kind new-svc) (service-kind s))
                                        (not (eq? (service-kind new-svc) mingetty-service-type))))
                                 acc)))
              (if dup-svc
                  (cond
                   ;; Exact match, keep one
                   ((equal? (service-value new-svc) (service-value dup-svc))
                    acc)
                   ;; New is default, keep old
                   ((equal? (service-type-default-value (service-kind new-svc))
                            (service-value new-svc))
                    acc)
                   ;; Old is default, keep new
                   ((equal? (service-type-default-value (service-kind dup-svc))
                            (service-value dup-svc))
                    (cons new-svc (remove (lambda (s) (eq? s dup-svc)) acc)))
                   ;; Conflict
                   (else
                    (error (format #f "edict: unresolvable duplicate service provided by multiple features: ~s"
                                   (service-kind new-svc)))))
                  ;; No duplicate, just cons
                  (cons new-svc acc))))
          '()
          services))

  (let* ((clean-feature-services (reverse (deduplicate-services feature-services)))
         (feature-kinds (map service-kind clean-feature-services)))
    (append
     (remove (lambda (svc)
               (and (memq (service-kind svc) feature-kinds)
                    (not (eq? (service-kind svc) mingetty-service-type))))
             base-services)
     clean-feature-services)))

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
            (extra-accounts (get-extensions composed user-accounts-target))
            (transformations (get-extensions composed os-transformations-target)))
       ;; Determine if a desktop environment is active.
       ;; When true, use %desktop-services (includes GDM, dbus, polkit, etc.)
       ;; instead of the minimal %base-services.
       (let ((has-de? (get-value 'has-desktop-environment? composed #f))
             (base-services (if (get-value 'has-desktop-environment? composed #f)
                                %desktop-services
                                %base-services)))
        (fold (lambda (proc os) (proc os))
             (operating-system
               ;; Kernel — auto-wired from feature values when present
               (kernel (or kern linux-libre))
               (firmware (or fw %base-firmware))
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
                        (shell (file-append zsh "/bin/zsh"))
                        (supplementary-groups
                         (delete-duplicates
                          (get-extensions composed user-groups-target)
                          string=?))))
                 extra-accounts
                 %base-user-accounts))

               (groups
                (append (get-extensions composed groups-target) %base-groups))
               (packages
                (append (map resolve-package (get-extensions composed system-packages-target))
                        %base-packages))
               (services
                (merge-services
                 base-services
                 (get-extensions composed system-services-target)))
               (name-service-switch %mdns-host-lookup-nss)

               ;; Machine-specific overrides come last and win:
               field ...)
             transformations))))))


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
         (packages (map resolve-package (get-extensions composed home-packages-target)))
         (services (get-extensions composed home-services-target))
         field ...)))))
