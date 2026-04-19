;;; Copyright © 2026 hirancph
;;;
;;; fonts.scm — Curated font stack feature.
;;;
;;; Installs a well-rounded set of fonts for terminal, UI, emoji, and
;;; CJK fallback.  Packages are contributed at the system level so they
;;; are available to all users (fontconfig picks them up automatically).

(define-module (edict features fonts)
  #:use-module (edict features)
  #:export (fonts-feature))

(define* (fonts-feature #:key
                        (nerd-fonts? #t)
                        (emoji? #t)
                        (cjk? #f)
                        (extra-fonts '()))
  "Curated font stack for desktop use.
NERD-FONTS? — install Nerd Font patched monospace fonts.
EMOJI? — install Noto Color Emoji.
CJK? — install CJK (Chinese/Japanese/Korean) fallback fonts.
EXTRA-FONTS — additional font package strings to install."

  ;; ── Validation ──
  (ensure-pred boolean? nerd-fonts?)
  (ensure-pred boolean? emoji?)
  (ensure-pred boolean? cjk?)
  (ensure-pred list? extra-fonts)

  (edict-feature
   #:name 'fonts
   #:provides '(fonts)
   #:requires '(base)
   #:extensions
   (list
    (apply contribute system-packages-target
           (append
            ;; Core UI fonts
            (list "font-fira-code"
                  "font-iosevka"
                  "font-iosevka-aile"
                  "font-liberation"
                  "font-dejavu")
            (if nerd-fonts?
                '("font-fira-mono")
                '())
            (if emoji?
                '("font-google-noto-emoji")
                '())
            (if cjk?
                '("font-google-noto-sans-cjk"
                  "font-google-noto-serif-cjk")
                '())
            extra-fonts)))))
