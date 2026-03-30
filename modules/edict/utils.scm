;;; Copyright © 2026 hirancph
;;;
;;; Shared utility procedures used across the edict configuration.
;;;
;;; Keep this module lean — only include genuinely reusable helpers.
;;; Feature-specific logic belongs in the feature modules themselves.

(define-module (edict utils)
  #:use-module (gnu packages)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-13)
  #:export (pkgs
            path-append))

(define (pkgs . names)
  "Resolve package specification strings to package objects.
Example: (pkgs \"git\" \"curl\" \"htop\")"
  (map specification->package names))

(define (path-append . parts)
  "Join path components with '/'.
Example: (path-append \"/home\" \"user\" \".config\") => \"/home/user/.config\""
  (string-join parts "/"))
