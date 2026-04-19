;;; Copyright © 2026 hirancph
;;;
;;; caelestia.scm — Fully declarative Caelestia/Quickshell desktop shell.
;;;
;;; Everything is built from local checkouts — no manual cloning or
;;; external package downloads needed:
;;;
;;;   files/quickshell-src/ — Quickshell compositor (git HEAD)
;;;   files/quickshell/     — Caelestia shell config + QML plugin
;;;
;;; This feature contributes:
;;;   - Quickshell-git (built from source, with IdleInhibitor)
;;;   - Caelestia QML plugin (audio viz, calculator, native services)
;;;   - XDG config files deployed declaratively
;;;   - Wayland compositor sentinel (waits for sockets)
;;;   - Session services (xdph, polkit agent, gnome-keyring, dbus)
;;;   - All desktop packages (themes, fonts, tools)
;;;
;;; Adapted from nehrbash's desktop/caelestia.scm.

(define-module (edict features caelestia)
  #:use-module (gnu home services)
  #:use-module (gnu home services desktop)
  #:use-module (gnu home services sound)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu packages audio)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages music)
  #:use-module (gnu packages polkit)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu packages qt)
  #:use-module (gnu packages wm)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages xorg)
  #:use-module (guix gexp)
  #:use-module (edict features)
  #:use-module (edict packages fonts)
  #:use-module (edict packages quickshell)
  #:use-module (edict services shepherd-helpers)
  #:use-module (edict services wayland-compositor)
  #:export (caelestia-feature))


;; ═══════════════════════════════════════════════════════════════════
;; Declarative Shell Config Deployment
;; ═══════════════════════════════════════════════════════════════════
;;
;; Deploy the entire Caelestia QML shell config from files/quickshell/
;; into ~/.config/quickshell/ via home-xdg-configuration-files-service.
;; This means the config is managed by Guix Home — no manual symlinks.

(define %caelestia-config-source
  (local-file "../../../files/quickshell"
              "caelestia-config"
              #:recursive? #t))


;; ═══════════════════════════════════════════════════════════════════
;; Session Helper Service Types
;; ═══════════════════════════════════════════════════════════════════

;; xdg-desktop-portal-hyprland — D-Bus activation fails on Guix
;; (upstream .service file references systemd).
(define home-xdph-service-type
  (service-type
   (name 'home-xdph)
   (extensions
    (list (service-extension home-shepherd-service-type
                             (lambda _
                               (list
                                (make-simple-shepherd-service
                                 'xdg-desktop-portal-hyprland
                                 #~(list #$(file-append
                                            xdg-desktop-portal-hyprland
                                            "/libexec/xdg-desktop-portal-hyprland"))
                                 #:requirement '(wayland-compositor)
                                 #:documentation
                                 "Run xdg-desktop-portal-hyprland for screen sharing."
                                 #:environment-variables
                                 #~(filter
                                    (lambda (s)
                                      (not (string-prefix? "LD_LIBRARY_PATH=" s)))
                                    (environ))))))
          (service-extension home-profile-service-type
                             (lambda _
                               (list xdg-desktop-portal-hyprland
                                     xdg-desktop-portal-gtk)))))
   (default-value #f)
   (description "Run xdg-desktop-portal-hyprland under shepherd.")))

;; hyprpolkitagent — polkit authentication prompts for Hyprland.
(define home-hyprpolkitagent-service-type
  (service-type
   (name 'home-hyprpolkitagent)
   (extensions
    (list (service-extension home-shepherd-service-type
                             (lambda _
                               (list
                                (make-simple-shepherd-service
                                 'hyprpolkitagent
                                 #~(list #$(file-append hyprpolkitagent
                                                        "/libexec/hyprpolkitagent"))
                                 #:requirement '(wayland-compositor)
                                 #:documentation
                                 "Run hyprpolkitagent for polkit authentication."
                                 #:environment-variables
                                 #~(cons (string-append
                                          "QT_PLUGIN_PATH="
                                          #$(file-append qtwayland
                                                         "/lib/qt6/plugins")
                                          ":"
                                          #$(file-append qtbase
                                                         "/lib/qt6/plugins"))
                                         (environ))))))
          (service-extension home-profile-service-type
                             (lambda _ (list hyprpolkitagent)))))
   (default-value #f)
   (description "Run hyprpolkitagent for polkit authentication prompts.")))

;; gnome-keyring-daemon — org.freedesktop.secrets over D-Bus.
(define home-gnome-keyring-service-type
  (service-type
   (name 'home-gnome-keyring)
   (extensions
    (list (service-extension home-shepherd-service-type
                             (lambda _
                               (list
                                (make-simple-shepherd-service
                                 'gnome-keyring
                                 #~(list #$(file-append gnome-keyring
                                                        "/bin/gnome-keyring-daemon")
                                         "--start" "--foreground"
                                         "--components=secrets")
                                 #:documentation
                                 "Run gnome-keyring-daemon (secrets component)."))))
          (service-extension home-profile-service-type
                             (lambda _ (list gnome-keyring)))))
   (default-value #f)
   (description
    "Run gnome-keyring-daemon for libsecret consumers.")))


;; ═══════════════════════════════════════════════════════════════════
;; Quickshell Shepherd Service
;; ═══════════════════════════════════════════════════════════════════

(define* (quickshell-shepherd-service #:key
                                     (config-name "caelestia")
                                     (icon-theme "Adwaita"))
  "Return a Shepherd service that runs Quickshell with the given config."
  (shepherd-service
   (provision '(quickshell))
   (requirement '(wayland-compositor))
   (documentation "Run quickshell desktop shell.")
   (start
    #~(lambda _
        ((make-forkexec-constructor
          (append
           (list #$(file-append quickshell-git "/bin/quickshell"))
           (if (string-null? #$config-name) '() (list "-c" #$config-name))
           (list "-n"))
          #:environment-variables
          (cons*
           (string-append "QT_PLUGIN_PATH="
                          (getenv "HOME")
                          "/.guix-home/profile/lib/qt6/plugins")
           (string-append "QML_IMPORT_PATH="
                          (getenv "HOME")
                          "/.guix-home/profile/lib/qt6/qml")
           "QT_QPA_PLATFORM=wayland"
           (string-append "QS_ICON_THEME=" #$icon-theme)
           (string-append "WAYLAND_DISPLAY="
                          (or (getenv "WAYLAND_DISPLAY") "wayland-1"))
           (string-append "PATH="
                          #$(file-append lm-sensors "/bin")
                          ":" (getenv "PATH"))
           (string-append "CAELESTIA_XKB_RULES_PATH="
                          #$(file-append xkeyboard-config
                                         "/share/X11/xkb/rules/base.lst"))
           (filter (lambda (e)
                     (not (or (string-prefix? "QT_PLUGIN_PATH=" e)
                              (string-prefix? "QML_IMPORT_PATH=" e)
                              (string-prefix? "QT_QPA_PLATFORM=" e)
                              (string-prefix? "WAYLAND_DISPLAY=" e)
                              (string-prefix? "PATH=" e))))
                   (environ)))
          #:log-file
          (string-append (getenv "XDG_STATE_HOME")
                         "/log/quickshell.log")))))
   (stop #~(make-kill-destructor))
   (respawn? #t)
   (respawn-limit #~'(3 . 10))
   (respawn-delay 5)))


;; ═══════════════════════════════════════════════════════════════════
;; The Caelestia Feature
;; ═══════════════════════════════════════════════════════════════════

(define* (caelestia-feature #:key
                            (quickshell-config "caelestia")
                            (icon-theme "Adwaita")
                            (gnome-keyring? #t)
                            (extra-packages '()))
  "Fully declarative Caelestia desktop shell on Quickshell.
Quickshell is built from git, the QML plugin is compiled from
files/quickshell/, and shell config files are deployed into
~/.config/quickshell/ by Guix Home."

  ;; ── Validation ──
  (ensure-pred string? quickshell-config)
  (ensure-pred string? icon-theme)
  (ensure-pred boolean? gnome-keyring?)
  (ensure-pred list? extra-packages)

  (edict-feature
   #:name 'caelestia
   #:provides '(caelestia desktop-shell)
   #:requires '(hyprland desktop audio)
   #:scope 'home
   #:values `((has-caelestia? . #t)
              (quickshell-config . ,quickshell-config))
   #:extensions
   (list
    ;; ── Desktop packages ──
    (apply contribute home-packages-target
           (append
            (list
             ;; Quickshell + Caelestia plugin (custom-built from git)
             quickshell-git
             quickshell-caelestia-plugin
             qtwayland

             ;; Compositor & Wayland tooling
             libnotify cliphist fuzzel playerctl brightnessctl
             wlr-randr xdg-utils xkeyboard-config

             ;; Caelestia font deps: sans/clock = Rubik,
             ;; mono = CaskaydiaCove NF (or Fira Mono fallback),
             ;; icons = Material Symbols
             font-rubik
             font-material-symbols-rounded

             ;; Audio viz / calculator deps
             cava aubio libqalculate pavucontrol)
            extra-packages))

    ;; ── Deploy QML shell config declaratively ──
    ;; Ships the entire files/quickshell/ tree into
    ;; ~/.config/quickshell/ managed by Guix Home.
    (contribute home-services-target
                (simple-service 'caelestia-config
                                home-xdg-configuration-files-service-type
                                `(("quickshell" ,%caelestia-config-source))))

    ;; ── Shepherd services ──
    ;; Wayland compositor sentinel (waits for sockets)
    (contribute home-services-target
                (service home-wayland-compositor-service-type))

    ;; Quickshell desktop shell — use simple-service to avoid
    ;; duplicate home-shepherd-service-type merge failures.
    (contribute home-services-target
                (simple-service 'quickshell-shepherd
                                home-shepherd-service-type
                                (list (quickshell-shepherd-service
                                       #:config-name quickshell-config
                                       #:icon-theme icon-theme))))

    ;; Session services (Guix System needs these since systemd
    ;; doesn't manage them here)
    (contribute home-services-target
                (service home-dbus-service-type))

    ;; NOTE: PipeWire is contributed by audio-feature (required above).
    ;; Do NOT add home-pipewire-service-type here — it would duplicate.

    (contribute home-services-target
                (service home-xdph-service-type))

    (contribute home-services-target
                (service home-hyprpolkitagent-service-type))

    (apply contribute home-services-target
           (if gnome-keyring?
               (list (service home-gnome-keyring-service-type))
               '())))))
