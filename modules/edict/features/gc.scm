;;; Copyright © 2026 hirancph
;;;
;;; gc.scm — Garbage collection feature.
;;;
;;; Schedules a nightly cron job to automatically run the Guix garbage
;;; collector, preventing the store from filling up with old generations.

(define-module (edict features gc)
  #:use-module (gnu services)
  #:use-module (gnu services mcron)
  #:use-module (guix gexp)
  #:use-module (edict features)
  #:export (gc-feature))

(define* (gc-feature #:key
                     (gc-days 30)
                     (gc-free "5G"))
  "Nightly Guix Garbage Collection.
GC-DAYS: delete generations older than this.  GC-FREE: minimum free space."

  ;; ── Validation ──
  (ensure-pred integer? gc-days)
  (ensure-pred string? gc-free)

  (edict-feature
   #:name 'gc
   #:provides '(gc)
   #:requires '()
   #:values `((gc-days . ,gc-days)
              (gc-free . ,gc-free))
   #:extensions
   (list
    (contribute system-services-target
     (simple-service 'gc-cron-jobs
                     mcron-service-type
                     (list
                      #~(job "5 0 * * *"
                             (string-append
                              "guix gc --delete-generations="
                              #$(number->string gc-days)
                              "d -F "
                              #$gc-free))))))))
