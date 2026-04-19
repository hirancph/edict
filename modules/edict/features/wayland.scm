;;; Copyright © 2026 hirancph
;;;
;;; wayland.scm — Wayland/Hyprland environment variable feature.
;;;
;;; Sets the XDG, Qt, cursor, and toolkit environment variables needed
;;; for a properly functioning Wayland desktop under Hyprland.
;;; Without these, Electron apps, Firefox, Qt apps, and cursors
;;; misbehave.  Inspired by nehrbash's env var groups.

(define-module (edict features wayland)
  #:use-module (gnu home services)
  #:use-module (edict features)
  #:export (wayland-feature))

(define* (wayland-feature #:key
                          (desktop-name "Hyprland")
                          (cursor-theme "Adwaita")
                          (cursor-size 24)
                          (nvidia? #f)
                          (extra-env-vars '()))
  "Wayland session environment variables for Hyprland.
Sets XDG session type, toolkit backends (Qt, GTK, SDL, Electron),
cursor theme/size, and Mozilla Wayland hints.
NVIDIA? — add NVIDIA-specific driver selection env vars."

  ;; ── Validation ──
  (ensure-pred string? desktop-name)
  (ensure-pred string? cursor-theme)
  (ensure-pred integer? cursor-size)
  (ensure-pred boolean? nvidia?)
  (ensure-pred list? extra-env-vars)

  (let ((size-str (number->string cursor-size)))
    (edict-feature
     #:name 'wayland
     #:provides '(wayland wayland-env)
     #:requires '(desktop)
     #:scope 'home
     #:extensions
     (list
      (contribute home-services-target
       (simple-service 'wayland-env-vars
                       home-environment-variables-service-type
                       (append
                        ;; XDG session
                        `(("XDG_CURRENT_DESKTOP" . ,desktop-name)
                          ("XDG_SESSION_DESKTOP" . ,desktop-name)
                          ("XDG_SESSION_TYPE" . "wayland"))

                        ;; Toolkit backends
                        '(("SDL_VIDEODRIVER" . "wayland")
                          ("MOZ_ENABLE_WAYLAND" . "1")
                          ("CLUTTER_BACKEND" . "wayland")
                          ("ELECTRON_OZONE_PLATFORM_HINT" . "auto")
                          ("_JAVA_AWT_WM_NONREPARENTING" . "1"))

                        ;; Qt
                        '(("QT_AUTO_SCREEN_SCALE_FACTOR" . "1")
                          ("QT_QPA_PLATFORM" . "wayland;xcb")
                          ("QT_QPA_PLATFORMTHEME" . "qt5ct")
                          ("QT_WAYLAND_DISABLE_WINDOWDECORATION" . "1"))

                        ;; Cursor — set both X and Hyprland cursor vars
                        `(("XCURSOR_THEME" . ,cursor-theme)
                          ("XCURSOR_SIZE" . ,size-str)
                          ("HYPRCURSOR_THEME" . ,cursor-theme)
                          ("HYPRCURSOR_SIZE" . ,size-str)
                          ("GDK_SCALE" . "1"))

                        ;; Flatpak XDG_DATA_DIRS integration
                        '(("XDG_DATA_DIRS" .
                           "$XDG_DATA_DIRS:$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share"))

                        ;; NVIDIA-specific — driver selection for Wayland
                        (if nvidia?
                            '(("LIBVA_DRIVER_NAME" . "nvidia")
                              ("GBM_BACKEND" . "nvidia-drm")
                              ("__GLX_VENDOR_LIBRARY_NAME" . "nvidia")
                              ("__GL_GSYNC_ALLOWED" . "1")
                              ("__GL_VRR_ALLOWED" . "1")
                              ("NVD_BACKEND" . "direct")
                              ;; Guix System has no /usr/lib — Hyprland,
                              ;; Quickshell, and Qt need this to find the
                              ;; nonguix NVIDIA driver shared objects.
                              ("LD_LIBRARY_PATH" .
                               "/run/current-system/profile/lib:$HOME/.guix-home/profile/lib"))
                            '())

                        extra-env-vars)))))))
