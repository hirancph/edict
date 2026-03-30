;;; Copyright © 2026 hirancph
;;;
;;; features.scm — The edict extensible feature engine.
;;;
;;; A "feature" is a composable unit that contributes extensions to
;;; specific configuration targets (e.g., system services, user packages).
;;; Features explicitly declare what they require and provide, and are
;;; automatically ordered via a topological sort.
;;;
;;; Design principles (SICP §2.2, §3.5):
;;;   1. Features are data, constructed by procedures — combinable like lists.
;;;   2. Targets are named extension points — a protocol, not a type hierarchy.
;;;   3. Composition is explicit — compose-features returns plain data.
;;;   4. Values flow forward — topological sort ensures providers run first.

(define-module (edict features)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (srfi srfi-26)
  #:use-module (srfi srfi-35)
  #:use-module (ice-9 match)
  #:use-module (ice-9 format)
  #:export (;; Built-in Targets
            system-packages-target
            system-services-target
            home-packages-target
            home-services-target
            kernel-arguments-target
            kernel-modules-target
            groups-target
            user-groups-target
            user-accounts-target

            ;; Feature record
            edict-feature
            edict-feature?
            edict-feature-name
            edict-feature-provides
            edict-feature-requires
            edict-feature-values
            edict-feature-extensions
            edict-feature-scope

            ;; Extensions
            contribute
            get-extensions

            ;; Composition
            compose-features
            composed-features?
            composed-values
            composed-extensions
            composed-features

            ;; Value store
            get-value
            require-value
            make-feature-values

            ;; Validation
            ensure-pred

            ;; Feature list manipulation
            modify-features

            ;; Introspection
            describe-composition))

;; ═══════════════════════════════════════════════════════════════════
;; Built-in Targets
;; ═══════════════════════════════════════════════════════════════════
;;
;; Targets are symbols naming an extension point. Features contribute
;; to targets via (contribute <target> . items). The build module
;; reads each target to wire packages, services, etc. into the final
;; operating-system or home-environment.

(define system-packages-target  'system-packages)
(define system-services-target   'system-services)
(define home-packages-target     'home-packages)
(define home-services-target     'home-services)
(define kernel-arguments-target  'kernel-arguments)
(define kernel-modules-target    'kernel-modules)
(define groups-target            'groups)
(define user-groups-target       'user-groups)
(define user-accounts-target     'user-accounts)

;; ═══════════════════════════════════════════════════════════════════
;; Validation
;; ═══════════════════════════════════════════════════════════════════

(define-syntax ensure-pred
  (syntax-rules ()
    "Validate that FIELD satisfies PRED. Raises a clear error if not.
Usage: (ensure-pred integer? port)"
    ((_ pred field)
     (unless (pred field)
       (error (format #f "edict: validation failed — '~a' does not satisfy ~a (got: ~a)"
                      'field (procedure-name pred) field))))))

;; ═══════════════════════════════════════════════════════════════════
;; Feature & Extension Records
;; ═══════════════════════════════════════════════════════════════════

(define-record-type <edict-extension>
  (%make-edict-extension target payload)
  edict-extension?
  (target  edict-extension-target)
  (payload edict-extension-payload))

(define (contribute target . payload)
  "Create an extension contributing the PAYLOAD items to TARGET.
Example:
  (contribute system-packages-target git vim nss-certs)
  (contribute system-services-target (service openssh-service-type ...))"
  (%make-edict-extension target payload))

(define-record-type <edict-feature>
  (%make-edict-feature name provides requires values extensions scope)
  edict-feature?
  (name       edict-feature-name)
  (provides   edict-feature-provides)
  (requires   edict-feature-requires)
  (values     edict-feature-values)
  (extensions edict-feature-extensions)
  (scope      edict-feature-scope))

(define* (edict-feature #:key
                        (name 'unnamed)
                        (provides '())
                        (requires '())
                        (values '())
                        (extensions '())
                        (scope 'both))
  "Define a composable feature.

NAME        — symbol identifying this feature (for debugging/introspection)
PROVIDES    — list of symbols this feature makes available
REQUIRES    — list of symbols that must be provided before this feature
VALUES      — alist of key-value pairs shared across features
EXTENSIONS  — list of (contribute <target> ...) extension records
SCOPE       — 'system, 'home, or 'both (default: 'both)

Features are composed with compose-features, which topologically sorts
them based on requires/provides and merges their values and extensions."
  (ensure-pred symbol? name)
  (ensure-pred list? provides)
  (ensure-pred list? requires)
  (ensure-pred list? values)
  (ensure-pred list? extensions)
  (unless (memq scope '(system home both))
    (error (format #f "edict: feature '~a' has invalid scope '~a' — must be 'system, 'home, or 'both"
                   name scope)))
  (%make-edict-feature name provides requires values extensions scope))

;; ═══════════════════════════════════════════════════════════════════
;; Value Helpers
;; ═══════════════════════════════════════════════════════════════════

(define-syntax make-feature-values
  (syntax-rules ()
    "Ergonomic macro to create a feature values alist from bindings.
Example:
  (let ((kernel linux) (firmware (list linux-firmware)))
    (make-feature-values kernel firmware))
  => ((kernel . <linux>) (firmware . (<linux-firmware>)))"
    ((_ field ...)
     (list (cons 'field field) ...))))

;; ═══════════════════════════════════════════════════════════════════
;; Topological Sort
;; ═══════════════════════════════════════════════════════════════════

(define (tsort features)
  "Sort FEATURES topologically based on their requires/provides fields.
Uses Kahn's algorithm: repeatedly extract features whose requirements
are already satisfied, until the list is empty or a cycle is detected."
  (define (provides-symbol? feature sym)
    (memq sym (edict-feature-provides feature)))

  (define (find-provider sym)
    (find (lambda (f) (provides-symbol? f sym)) features))

  (let loop ((remaining features)
             (sorted '()))
    (if (null? remaining)
        (reverse sorted)
        (let* ((ready (filter (lambda (f)
                                (every (lambda (req)
                                         (let ((provider (find-provider req)))
                                           (or (not provider)
                                               (memq provider sorted))))
                                       (edict-feature-requires f)))
                              remaining)))
          (when (null? ready)
            (let ((names (map edict-feature-name remaining)))
              (error (format #f "edict: circular dependency among features: ~a" names))))
          (loop (lset-difference eq? remaining ready)
                (append (reverse ready) sorted))))))

;; ═══════════════════════════════════════════════════════════════════
;; Composition & Extraction
;; ═══════════════════════════════════════════════════════════════════

(define-record-type <composed-features>
  (%make-composed-features features values extensions)
  composed-features?
  (features   composed-features)
  (values     composed-values)
  (extensions composed-extensions))

(define* (compose-features features #:key (scope 'both))
  "Topologically sort FEATURES and merge into a composed-features record.

SCOPE — optional filter: 'system, 'home, or 'both (default).
When 'system, only features with scope 'system or 'both are included.
When 'home, only features with scope 'home or 'both are included.

Raises an error on duplicate value keys to prevent silent conflicts.
To intentionally override a value, use modify-features to remove the
feature providing the original value before composing."
  (let* ((scoped (if (eq? scope 'both)
                     features
                     (filter (lambda (f)
                               (let ((s (edict-feature-scope f)))
                                 (or (eq? s 'both) (eq? s scope))))
                             features)))
         (sorted (tsort scoped))
         (all-values (append-map edict-feature-values sorted)))

    ;; Check for duplicate value keys
    (let check ((remaining all-values)
                (seen '()))
      (unless (null? remaining)
        (let ((key (caar remaining)))
          (when (assq key seen)
            (let* ((first-feature
                    (find (lambda (f) (assq key (edict-feature-values f))) sorted))
                   (second-feature
                    (find (lambda (f)
                            (and (not (eq? f first-feature))
                                 (assq key (edict-feature-values f))))
                          sorted)))
              (error (format #f "edict: duplicate value key '~a' — provided by both '~a' and '~a'. Use modify-features to resolve."
                             key
                             (edict-feature-name first-feature)
                             (edict-feature-name second-feature)))))
          (check (cdr remaining)
                 (cons (car remaining) seen)))))

    (%make-composed-features
     sorted
     all-values
     (append-map edict-feature-extensions sorted))))

(define (get-extensions composed target)
  "Extract and concatenate all payloads contributed to TARGET."
  (append-map edict-extension-payload
              (filter (lambda (ext) (eq? (edict-extension-target ext) target))
                      (composed-extensions composed))))

;; ═══════════════════════════════════════════════════════════════════
;; Value Store
;; ═══════════════════════════════════════════════════════════════════

(define* (get-value key composed #:optional (default '*unset*))
  "Retrieve KEY from the composed value store.
If KEY is not found and no DEFAULT is given, raise an error.
If KEY is not found and DEFAULT is given, return DEFAULT."
  (let ((pair (assq key (composed-values composed))))
    (if pair
        (cdr pair)
        (if (eq? default '*unset*)
            (error (format #f "edict: required value '~a' not provided by any feature" key))
            default))))

(define (require-value key composed)
  "Retrieve KEY from the composed value store, erroring if absent.
Alias for (get-value key composed) without a default."
  (get-value key composed))

;; ═══════════════════════════════════════════════════════════════════
;; Feature List Manipulation
;; ═══════════════════════════════════════════════════════════════════

(define (modify-features features . operations)
  "Apply OPERATIONS to a feature list. Supported operations:

  (modify-features my-features
    '(delete ssh)                          ;; Remove a feature by name
    `(replace ssh ,(ssh-feature #:port 22)))  ;; Replace a feature
    `(append ,(docker-feature))            ;; Add a new feature

Returns a new list; does not mutate the original."
  (fold (lambda (op feats)
          (match op
            (('delete name)
             (remove (lambda (f) (eq? (edict-feature-name f) name)) feats))
            (('replace name new-feature)
             (map (lambda (f)
                    (if (eq? (edict-feature-name f) name)
                        new-feature
                        f))
                  feats))
            (('append new-feature)
             (append feats (list new-feature)))
            (_ (error "edict: unknown modify-features operation" op))))
        features
        operations))

;; ═══════════════════════════════════════════════════════════════════
;; Introspection
;; ═══════════════════════════════════════════════════════════════════

(define (describe-composition composed)
  "Print a human-readable summary of a composed feature set.
Shows: feature order, all values, and extensions per target."
  (define (section title)
    (format #t "\n~a\n~a\n" title (make-string (string-length title) #\═)))

  (define all-targets
    (list system-packages-target system-services-target
          home-packages-target home-services-target
          kernel-arguments-target kernel-modules-target
          groups-target user-groups-target user-accounts-target))

  (section "Edict Composition Report")

  ;; Feature order
  (format #t "\n  Features (topological order):\n")
  (for-each
   (lambda (f)
     (format #t "    • ~a  [scope: ~a, provides: ~a, requires: ~a]\n"
             (edict-feature-name f)
             (edict-feature-scope f)
             (edict-feature-provides f)
             (edict-feature-requires f)))
   (composed-features composed))

  ;; Values
  (format #t "\n  Values:\n")
  (for-each
   (lambda (pair)
     (format #t "    ~a = ~a\n" (car pair) (cdr pair)))
   (composed-values composed))

  ;; Extensions per target
  (format #t "\n  Extensions:\n")
  (for-each
   (lambda (target)
     (let ((items (get-extensions composed target)))
       (unless (null? items)
         (format #t "    [~a] (~a items)\n" target (length items)))))
   all-targets)

  (newline))
