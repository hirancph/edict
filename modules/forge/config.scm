;;; Copyright © 2026 hirancph
;;;
;;; This module defines global configuration constants and paths.
;;; All system-wide settings that might vary per-user or per-host
;;; should be defined here so they can be imported anywhere.

(define-module (forge config)
  #:use-module (guix utils)
  #:export (%config-dir
            %modules-dir
            %user-name
            %full-name
            %timezone
            %locale))

;; ——— Paths ———

;; Automatically resolves to the repository root based on this file's location.
;; (forge config) => .../modules/forge/config.scm => ../../ => repo root
(define %config-dir
  (dirname (dirname (current-source-directory))))

(define %modules-dir
  (string-append %config-dir "/modules"))

;; ——— User ———

(define %user-name "hirancph")
(define %full-name "hirancph")

;; ——— Locale & Timezone ———

(define %timezone "Asia/Kolkata")
(define %locale "en_IN.utf8")
