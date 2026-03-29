;;; Copyright © 2026 hirancph
;;;
;;; Shared utility procedures used across the configuration.
;;; Place helpers here that are used by multiple modules to avoid duplication.

(define-module (edict utils)
  #:use-module (gnu packages)
  #:use-module (srfi srfi-1)
  #:export (pkgs
            path-append))

(define (pkgs . names)
  "Resolve a list of package specification strings to actual package objects.
Example: (pkgs \"git\" \"curl\" \"htop\")"
  (map specification->package names))

(define (path-append . parts)
  "Join path components with '/'.
Example: (path-append \"/home\" \"user\" \".config\") => \"/home/user/.config\""
  (string-join parts "/"))
