;;; Copyright © 2026 hirancph
;;;
;;; hyprland.scm — Hyprland compositor feature (fully configured).
;;;
;;; Installs Hyprland, deploys the full configuration tree
;;; (hyprland.conf + sub-configs, hypridle, XDG portal routing),
;;; registers a wayland-sessions .desktop entry for greetd/tuigreet,
;;; contributes XDG portal packages, and runs hypridle as a user daemon.
;;;
;;; Adapted from nehrbash's Hyprland/Caelestia setup.

(define-module (edict features hyprland)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu home services)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu packages wm)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages xdisorg)
  #:use-module (guix gexp)
  #:use-module (edict features)
  #:use-module (edict services shepherd-helpers)
  #:export (hyprland-feature))

;; ═══════════════════════════════════════════════════════════════════
;; Declarative Config Deployment
;; ═══════════════════════════════════════════════════════════════════
;;
;; The entire files/hypr/ tree → ~/.config/hypr/
;; The files/xdg-desktop-portal/ → ~/.config/xdg-desktop-portal/
;; Managed by Guix Home — no manual symlinks needed.

(define %hypr-config-source
  (local-file "../../files/hypr"
              "hypr-config"
              #:recursive? #t))

(define %xdg-portal-config-source
  (local-file "../../files/xdg-desktop-portal"
              "xdg-desktop-portal-config"
              #:recursive? #t))


;; ═══════════════════════════════════════════════════════════════════
;; Hypridle Shepherd Service
;; ═══════════════════════════════════════════════════════════════════

(define home-hypridle-service-type
  (service-type
   (name 'home-hypridle)
   (extensions
    (list (service-extension home-shepherd-service-type
                             (lambda _
                               (list
                                (make-simple-shepherd-service
                                 'hypridle
                                 #~(list #$(file-append hypridle
                                                        "/bin/hypridle"))
                                 #:requirement '(wayland-compositor)
                                 #:documentation
                                 "Run hypridle for idle/lock management."))))
          (service-extension home-profile-service-type
                             (lambda _ (list hypridle)))))
   (default-value #f)
   (description "Run hypridle under shepherd for idle timeout and DPMS.")))


;; ═══════════════════════════════════════════════════════════════════
;; The Hyprland Feature
;; ═══════════════════════════════════════════════════════════════════

(define* (hyprland-feature #:key
                           (xdg-portals? #t)
                           (hypridle? #t))
  "Hyprland Wayland compositor — fully configured.
Installs Hyprland as a system package, deploys the full config tree
(hyprland.conf + modular sub-configs), registers a .desktop entry for
greetd, adds XDG portals, deploys portal routing config, and runs
hypridle for idle/lock management.

XDG-PORTALS? — install XDG desktop portals (default: #t).
HYPRIDLE? — run hypridle idle daemon under shepherd (default: #t)."

  ;; ── Validation ──
  (ensure-pred boolean? xdg-portals?)
  (ensure-pred boolean? hypridle?)

  (edict-feature
   #:name 'hyprland
   #:provides '(hyprland window-manager)
   #:requires '(desktop)
   #:scope 'both
   #:values '((has-hyprland? . #t))
   #:extensions
   (list
    ;; ── System packages ──
    ;; Hyprland must be in system packages so greetd can find it.
    (apply contribute system-packages-target
           (append
            (list "hyprland")
            (if xdg-portals?
                (list "xdg-desktop-portal"
                      "xdg-desktop-portal-hyprland"
                      "xdg-desktop-portal-gtk")
                '())))

    ;; ── Register .desktop entry for greetd/tuigreet ──
    (contribute system-services-target
     (extra-special-file
      "/run/current-system/profile/share/wayland-sessions/hyprland.desktop"
      (plain-file "hyprland.desktop"
                  "[Desktop Entry]
Name=Hyprland
Comment=A dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
DesktopNames=Hyprland\n")))

    ;; ── Home packages ──
    ;; Core Hyprland utilities needed by keybinds and shell
    (contribute home-packages-target
               "wl-clipboard"   ;; Wayland clipboard (cliphist stores)
               "grim"           ;; Screenshot tool
               "slurp"          ;; Region selection
               "swappy"         ;; Screenshot annotation
               "hyprpicker"     ;; Color picker
               "wlr-randr"      ;; Wayland display config
               "wtype"          ;; Wayland keyboard input (shift+backspace)
               "alacritty"      ;; Terminal emulator (default $terminal)
               "wayfreeze")     ;; Freeze screen for area selection

    ;; ── Deploy Hyprland config tree declaratively ──
    ;; Ships the entire files/hypr/ into ~/.config/hypr/
    ;; and files/xdg-desktop-portal/ into ~/.config/xdg-desktop-portal/
    (contribute home-services-target
                (simple-service 'hyprland-config
                                home-xdg-configuration-files-service-type
                                `(("hypr" ,%hypr-config-source)
                                  ("xdg-desktop-portal"
                                   ,%xdg-portal-config-source))))

    ;; ── Hypridle shepherd service ──
    (apply contribute home-services-target
           (if hypridle?
               (list (service home-hypridle-service-type))
               '())))))
