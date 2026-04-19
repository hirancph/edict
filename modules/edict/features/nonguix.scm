;;; Copyright © 2026 hirancph
;;;
;;; nonguix.scm — Non-free kernel and substitute server configuration.
;;;
;;; The kernel, firmware, and initrd are published as values so that
;;; the build module can automatically wire them into operating-system.
;;; Substitute URLs are read from substitute-urls.txt so the Guix daemon's
;;; built-in defaults stay in sync with the Makefile.
;;; This is a system-only feature — it has no effect on home-environment.

(define-module (edict features nonguix)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (guix gexp)
  #:use-module (srfi srfi-13)
  #:use-module (ice-9 rdelim)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu system linux-initrd)
  #:use-module (edict features)
  #:use-module (edict config)
  #:export (nonguix-feature))

;; Read substitute URLs from substitute-urls.txt so the daemon's baked-in
;; defaults stay in sync with the Makefile (which passes --substitute-urls
;; from the same file).  Edit that file to change mirrors instantly.
(define %substitute-urls
  (call-with-input-file
      (string-append %config-dir "/substitute-urls.txt")
    (lambda (port)
      (let loop ((acc '()))
        (let ((line (read-line port)))
          (if (eof-object? line)
              (reverse acc)
              (let ((trimmed (string-trim-both
                              (car (string-split line #\#)))))
                (if (string-null? trimmed)
                    (loop acc)
                    (loop (cons trimmed acc))))))))))

(define %nonguix-authorized-key
  (plain-file "nonguix.pub"
    "(public-key (ecc (curve Ed25519) (q #C1FD53E5D4CE971933EC50C9F307AE2171A2D3B52C804642A7A35F84F3A4EA98#)))"))

(define* (nonguix-feature #:key
                          (kernel linux)
                          (firmware (list linux-firmware))
                          (initrd microcode-initrd))
  "Non-free kernel, firmware, initrd, and substitute server.
Publishes kernel/firmware/initrd as values so the build module can
wire them in automatically.  Substitute URLs are read from
substitute-urls.txt.  System-scope only."

  ;; ── Validation ──
  (ensure-pred list? firmware)

  (edict-feature
   #:name 'nonguix
   #:provides '(nonguix kernel)
   #:requires '()
   #:scope 'system
   #:values (make-feature-values kernel firmware initrd)
   #:extensions
   (list
    (contribute system-services-target
     (simple-service 'add-nonguix-substitutes
                     guix-service-type
                     (guix-extension
                      (substitute-urls
                       %substitute-urls)
                      (authorized-keys
                       (append (list %nonguix-authorized-key)
                               %default-authorized-guix-keys))))))))
