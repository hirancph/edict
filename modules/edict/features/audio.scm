;;; Copyright © 2026 hirancph
;;;
;;; audio.scm — PipeWire audio stack feature.
;;;
;;; Provides PipeWire + WirePlumber as a home service (the modern
;;; approach, matching daviwil and nehrbash).  System-level packages
;;; for CLI control are also contributed.

(define-module (edict features audio)
  #:use-module (gnu home services)
  #:use-module (gnu home services sound)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pulseaudio)
  #:use-module (edict features)
  #:export (audio-feature))

(define* (audio-feature #:key
                        (pavucontrol? #t))
  "PipeWire audio stack with WirePlumber session manager.
Runs as a home service (user session).  Optionally installs pavucontrol
for GUI volume control."

  ;; ── Validation ──
  (ensure-pred boolean? pavucontrol?)

  (edict-feature
   #:name 'audio
   #:provides '(audio pipewire)
   #:requires '(desktop)
   #:scope 'both
   #:values '((has-audio? . #t))
   #:extensions
   (list
    ;; PipeWire runs as a home (user) service — this is the modern approach.
    (contribute home-services-target
                (service home-pipewire-service-type))

    (apply contribute home-packages-target
           (append
            (list "playerctl")
            (if pavucontrol?
                (list "pavucontrol")
                '()))))))
