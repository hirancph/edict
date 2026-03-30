;;; Copyright © 2026 hirancph
;;;
;;; home/vessel.scm — Home environment for the "vessel" host.
;;;
;;; This is the user-level counterpart to systems/vessel.scm.
;;; It reuses the same composed features (from (edict hosts vessel))
;;; to extract home-packages and home-services.
;;;
;;; Apply with:
;;;   make home

(define-module (edict home vessel)
  #:use-module (gnu home)
  #:use-module (gnu home services)
  #:use-module (edict features)
  #:use-module (edict build)
  #:use-module (edict hosts vessel))


;; ═══════════════════════════════════════════════════════════════════
;; Home Environment
;; ═══════════════════════════════════════════════════════════════════
;;
;; Home-level packages and services are extracted from the same
;; composed features used by the system.  Add vessel-specific
;; user configuration as additional home-environment fields below.

(edict-home-environment %vessel)
