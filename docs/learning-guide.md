# Learning Edict — A File-by-File Guide

Welcome! This guide walks you through every file in this Guix configuration repository, one at a time, in a logical learning order. Each section teaches you **what the file does**, **key concepts**, and **how it connects to the rest of the system**.

---

## Table of Contents

1. [`channels.scm`](#1-channelsscm) — Where to get software
2. [`Makefile`](#2-makefile) — Your command center
3. [`modules/edict/config.scm`](#3-modulesedictconfigscm) — Global constants
4. [`modules/edict/utils.scm`](#4-modulesedictutilsscm) — Shared helpers
5. [`modules/edict/features.scm`](#5-modulesedictfeaturesscm) — The feature engine (the heart)
6. [`modules/edict/build.scm`](#6-modulesedictbuildscm) — The builders
7. [`modules/edict/features/base.scm`](#7-modulesedictfeaturesbasescm) — A simple feature
8. [`modules/edict/features/nonguix.scm`](#8-modulesedictfeaturesnonguixscm) — A feature with values
9. [`modules/edict/hosts/vessel.scm`](#9-modulesedicthostsvesselscm) — Feature selection
10. [`modules/edict/systems/vessel.scm`](#10-modulesedictsystemsvesselscm) — System declaration
11. [`modules/edict/home/vessel.scm`](#11-modulesedicthomevesselscm) — Home environment

---

## 1. `channels.scm`

**What it is:** The entry point for `guix pull`. It tells Guix *where* to fetch packages and system definitions from.

### The Code

```scheme
(list
 ;; Official GNU Guix channel
 (channel
  (name 'guix)
  (url "https://codeberg.org/guix/guix.git")
  (introduction
   (make-channel-introduction
    "9edb3f66fd807b096b48283debdcddccfea34bad"
    (openpgp-fingerprint
    "BBB0 2DFC 2603 4E8C AA15  7656 53E6 AF4F 1524 3DC2"))))

 ;; Nonguix — nonfree packages (linux kernel, NVIDIA drivers, etc.)
 (channel
  (name 'nonguix)
  (url "https://gitlab.com/nonguix/nonguix")
  (introduction
   (make-channel-introduction
    "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
    (openpgp-fingerprint
     "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5")))))
```

### Key Concepts

- **Channel:** A Git repository that Guix pulls packages from. The official `guix` channel has free software only. The `nonguix` channel provides non-free packages like the standard Linux kernel and NVIDIA drivers.
- **Introduction + Fingerprint:** Cryptographic signatures. Guix verifies that the channel is authentic using OpenPGP. These fingerprints are pinned to specific commit hashes so you always get a verified, reproducible history.
- **Why two channels?** Guix defaults to only free software. If you need proprietary drivers (like NVIDIA), you add `nonguix` as a second channel.

### How it's used

The `Makefile` references this file:
```sh
guix pull -C channels.scm
```
This updates your local Guix to the latest commits from these channels.

---

## 2. `Makefile`

**What it is:** A convenience layer. Under the hood, everything is just `guix system reconfigure` or `guix home reconfigure` with the right flags. The Makefile saves you from typing them every time.

### Key Targets

| Target | What it does |
|---|---|
| `make pull` | Runs `guix pull -C channels.scm` to update channels |
| `make system` | Reconfigures the OS. Uses `-L` to load our modules and points to `modules/edict/systems/$(HOST).scm` |
| `make home` | Reconfigures the home environment similarly |
| `make deploy` | Runs both `system` and `home` |
| `make gc` | Garbage-collects generations older than 30 days |

### Important Variables

```makefile
HOST ?= vessel
MODULES_DIR := $(GUIX_CONFIG_DIR)/modules
export GUIX_PACKAGE_PATH := $(MODULES_DIR)
```

- **`HOST`:** Defaults to `vessel`. Override it: `make system HOST=laptop`
- **`GUIX_PACKAGE_PATH`:** Tells Guix where to find custom `(edict ...)` modules. Without this, `(use-module (edict features))` would fail.

### The system target, decoded

```sh
sudo -E guix system reconfigure \
  --substitute-urls="https://ci.guix.gnu.org ..." \
  -L $(MODULES_DIR) \
  $(MODULES_DIR)/edict/systems/$(HOST).scm
```

- `-L`: Adds our modules directory to Guix's load path.
- `--substitute-urls`: Pre-populated binary cache servers (avoids building from source).
- The final argument is the `.scm` file that defines the operating system.

---

## 3. `modules/edict/config.scm`

**What it is:** A single place for global constants — username, locale, timezone, and repository paths.

### The Code

```scheme
(define-module (edict config)
  #:export (%config-dir %modules-dir %user-name %full-name %timezone %locale))

(define %config-dir
  (dirname (dirname (current-source-directory))))

(define %user-name "hirancph")
(define %timezone "Asia/Kolkata")
(define %locale "en_IN.utf8")
```

### Key Concepts

- **`define-module`:** Declares a Guile module. `(edict config)` maps to the file path `modules/edict/config.scm`. Other files import it with `#:use-module (edict config)`.
- **`#:export`:** Lists which variables/procedures are public.
- **`%` prefix:** A Guix convention — global constants start with `%` to stand out. It has no special meaning to the language.
- **`current-source-directory`:** Returns the directory of the current file. Two `dirname` calls go up from `modules/edict/` to the repo root. This means paths work correctly no matter where you clone the repo.

### Who uses this?

- `build.scm` imports `%user-name` and `%locale` to set up user accounts.
- `systems/vessel.scm` imports `%timezone` and `%locale`.

---

## 4. `modules/edict/utils.scm`

**What it is:** Small, reusable helper functions used across feature modules.

### The Code

```scheme
(define-module (edict utils)
  #:export (pkgs path-append))

(define (pkgs . names)
  "Resolve package specification strings to package objects."
  (map specification->package names))

(define (path-append . parts)
  "Join path components with '/'."
  (string-join parts "/"))
```

### Key Concepts

- **`. names` (dot notation):** The dot means "collect all remaining arguments into a list." So `(pkgs "git" "vim" "htop")` binds `names` to `("git" "vim" "htop")`.
- **`specification->package`:** A Guix procedure that turns a string like `"git"` into an actual `<package>` object. Guix can resolve version pins like `"git@2.40.0"` too.
- **`string-join`:** From SRFI-13, joins a list of strings with a separator.

This module is intentionally kept lean — only genuinely shared helpers live here. Feature-specific logic belongs in the feature modules themselves.

---

## 5. `modules/edict/features.scm`

**What it is:** The heart of Edict. This ~260-line file defines the entire feature engine — the mechanism that makes this configuration composable instead of a monolithic mess.

### Core Idea

A **feature** is a self-contained unit (like "SSH server" or "NVIDIA driver") that:
1. Declares what it **provides** (e.g., `'ssh`)
2. Declares what it **requires** (e.g., `'networking`)
3. Publishes **values** for other features to read (e.g., kernel version)
4. **Contributes extensions** to named targets (e.g., packages to install, services to start)

### The Feature Record

```scheme
(define-record-type <edict-feature>
  (%make-edict-feature name provides requires values extensions scope)
  edict-feature?
  (name       edict-feature-name)
  (provides   edict-feature-provides)
  (values     edict-feature-values)
  (extensions edict-feature-extensions)
  (scope      edict-feature-scope))
```

A **record** is Scheme's equivalent of a struct or data class. Each feature has these six fields.

### The Constructor

```scheme
(define* (edict-feature #:key
                        (name 'unnamed)
                        (provides '())
                        (requires '())
                        (values '())
                        (extensions '())
                        (scope 'both))
  ...)
```

- **`define*`:** Defines a function with *optional keyword arguments*. Callers use `#:key value` syntax.
- **`scope`:** `'system`, `'home`, or `'both`. Controls whether the feature applies to the OS, the user home, or both.

### Extensions & Targets

```scheme
(define (contribute target . payload)
  "Create an extension contributing PAYLOAD items to TARGET.")
```

Targets are just symbols — named "buckets" that the builder later reads:

| Target | What goes in it |
|---|---|
| `system-packages-target` (`'system-packages`) | Packages installed system-wide |
| `system-services-target` (`'system-services`) | System daemons and services |
| `home-packages-target` (`'home-packages`) | User-level packages |
| `home-services-target` (`'home-services`) | User-level services |
| `kernel-arguments-target` | Kernel cmdline args |
| `user-groups-target` | User's supplementary groups |
| `groups-target` | System groups |
| `user-accounts-target` | Additional user accounts |

### Topological Sort

```scheme
(define (tsort features) ...)
```

This is the magic. It uses **Kahn's algorithm** to sort features so that requirements are always satisfied before dependents. **You never have to worry about the order you list features in.** The engine figures it out.

If there's a circular dependency (A requires B, B requires A), it raises an error with the names of the conflicting features.

### Composition

```scheme
(define* (compose-features features #:key (scope 'both))
  ...)
```

Takes a list of features, topologically sorts them, merges all their values and extensions, and returns a `<composed-features>` record. The `scope` parameter filters to system-only or home-only when needed.

### Value Sharing

```scheme
(define-syntax make-feature-values
  (syntax-rules ()
    ((_ field ...)
     (list (cons 'field field) ...))))
```

A convenience macro. `(make-feature-values kernel firmware)` produces `((kernel . <kernel-pkg>) (firmware . <fw-list>))`. Other features read these with:

```scheme
(get-value 'kernel composed #f)   ;; returns kernel or #f
(require-value 'kernel composed)  ;; returns kernel, errors if missing
```

### Feature Modification

```scheme
(define (modify-features features . operations)
  ...)
```

Lets you transform a feature list declaratively:

```scheme
(modify-features %base-features
  '(delete nvidia)                              ;; remove by name
  `(replace ssh ,(ssh-feature #:port 22))       ;; replace with new config
  `(append ,(docker-feature)))                  ;; add a new feature
```

### Introspection

```scheme
(describe-composition %vessel)
```

Prints a human-readable report: feature order, all values, and how many items each target has. This is your debugging tool.

---

## 6. `modules/edict/build.scm`

**What it is:** The builders. They take a `<composed-features>` record and produce actual Guix `operating-system` and `home-environment` records.

### The OS Builder Macro

```scheme
(define-syntax edict-operating-system
  (syntax-rules ()
    ((_ composed-expr field ...)
     (let* ((composed composed-expr)
            (kern (get-value 'kernel composed #f))
            (fw   (get-value 'firmware composed #f))
            (ird  (get-value 'initrd composed #f))
            ...)
       (operating-system
         (kernel (or kern linux-libre))
         (firmware (or fw %base-firmware))
         ...
         field ...))))
```

### How it works

1. **Auto-wired from feature values:** If any feature published `kernel`, `firmware`, or `initrd` values, they're used. Otherwise, Guix defaults (`linux-libre`, `%base-firmware`).
2. **Extracted from targets:** Packages, services, groups, users — all pulled via `get-extensions` from the appropriate targets.
3. **Desktop detection:** Checks `has-desktop-environment?` value to decide between `%base-services` and `%desktop-services`.
4. **Machine-specific fields:** The `field ...` at the end (bootloader, file-systems, etc.) come from the per-host file and *override* anything auto-wired above.

### Service Merging

```scheme
(define (merge-services base-services feature-services) ...)
```

If a feature provides a service whose type already exists in the base, the feature's version wins (unless it's the default value). If two *different* features provide conflicting services of the same type, an error is raised — no silent overwrites.

Exception: `mingetty-service-type` (TTY logins) is allowed multiple times since it's designed that way.

### The Home Builder

```scheme
(define-syntax edict-home-environment
  (syntax-rules ()
    ((_ composed-expr field ...)
     (home-environment
       (packages (map resolve-package (get-extensions composed home-packages-target)))
       (services (get-extensions composed home-services-target))
       field ...))))
```

Much simpler — just extracts home-level packages and services, plus any additional fields the host file adds.

---

## 7. `modules/edict/features/base.scm`

**What it is:** A simple, concrete feature example. It installs essential tools and sets up FHS symlinks.

### The Code

```scheme
(define* (base-feature #:key
                       (extra-packages '())
                       (extra-user-groups '()))
  (ensure-pred list? extra-packages)
  (ensure-pred list? extra-user-groups)

  (edict-feature
   #:name 'base
   #:provides '(base)
   #:requires '()
   #:extensions
   (list
    (apply contribute user-groups-target
           (append '("wheel" "kvm") extra-user-groups))

    (apply contribute system-packages-target
           (append (list "git" "vim" "make" "ntfs-3g" "exfat-utils" "fuse-exfat")
                   extra-packages))

    (contribute system-services-target
     (simple-service 'fhs-symlinks
                     special-files-service-type
                     `(("/bin/bash"    ,(file-append bash "/bin/bash"))
                       ("/usr/bin/env" ,(file-append coreutils "/bin/env"))))

     (simple-service 'ntfs-mount-rules udev-service-type (list ntfs-3g))))))
```

### Key Concepts

- **`ensure-pred`:** A validation macro from `features.scm`. If someone passes a non-list as `extra-packages`, you get a clear error instead of a cryptic crash later.
- **`#:provides '(base)`:** This feature makes "base" available. Other features can `#:requires '(base)`.
- **`#:requires '()`:** Base has no dependencies. It's the foundation.
- **`apply`:** Since we're building the list of groups/packages dynamically with `append`, we use `apply` to spread them as individual arguments to `contribute`.
- **`simple-service`:** A Guix helper that creates a service without needing a full `service-type` definition. The FHS symlinks make `/bin/bash` and `/usr/bin/env` work for scripts that expect traditional Linux paths.
- **Backtick-quasiquote:** `` `("/bin/bash" ,(file-append bash "/bin/bash")) `` — the backtick treats the list as data, but `,` evaluates `file-append`. This produces `("/bin/bash" "/gnu/store/...-bash-5.2/bin/bash")` at build time.

### Why no `#:scope`?

It defaults to `'both`. But base only contributes to system-level targets anyway, so it has no effect on home environments.

---

## 8. `modules/edict/features/nonguix.scm`

**What it is:** A feature that publishes values. This is the pattern for "I need to tell other features something."

### The Code

```scheme
(define* (nonguix-feature #:key
                          (kernel linux)
                          (firmware (list linux-firmware))
                          (initrd microcode-initrd))
  (ensure-pred list? firmware)

  (edict-feature
   #:name 'nonguix
   #:provides '(nonguix kernel)
   #:requires '()
   #:scope 'system
   #:values (make-feature-values kernel firmware initrd)
   #:extensions
   (list
    (contribute system-services-target
     (simple-service 'add-nonguix-substitutes
                     guix-service-type
                     (guix-extension
                      (substitute-urls
                       (append %default-substitute-urls
                               '("https://substitutes.nonguix.org")))
                      (authorized-keys
                       (append (list (plain-file "nonguix.pub" "..."))
                               %default-authorized-guix-keys))))))))
```

### Key Concepts

- **`#:scope 'system`:** This feature only applies to the OS, not home. You can't install a kernel at the user level.
- **`#:values (make-feature-values kernel firmware initrd)`:** Publishes these three as an alist. The builder reads them with `get-value` and wires them into the `operating-system`.
- **`#:provides '(nonguix kernel)`:** Provides *two* symbols. The `kernel` symbol lets other features depend on "a kernel being available" without caring which one.
- **What it contributes:** Adds the nonguix binary cache server and its signing key to the Guix daemon configuration. This lets you download pre-built non-free packages instead of compiling them.

### The flow

```
nonguix-feature publishes:  kernel → <linux-package>
build.scm reads:            (get-value 'kernel composed #f)
build.scm wires:            (kernel (or kern linux-libre))
```

If nonguix is in the feature list, the non-free `linux` kernel is used. If not, the free `linux-libre` is the fallback.

---

## 9. `modules/edict/hosts/vessel.scm`

**What it is:** The **single source of truth** for what features the "vessel" machine uses. Both the system config and home config import from here.

### The Code

```scheme
(define-module (edict hosts vessel)
  #:export (%vessel-features %vessel))

(define %vessel-features
  (list
   (nonguix-feature)            ;; non-free kernel + substitutes
   (nvidia-feature)             ;; NVIDIA proprietary GPU driver
   (desktop-feature)            ;; seat, D-Bus, PolicyKit, storage, power
   (gnome-feature)              ;; GNOME Desktop Environment
   (gc-feature)                 ;; Nightly garbage collection cron job
   (networking-feature)         ;; NetworkManager, Wi-Fi, Bluetooth, NTP
   (ssh-feature #:port 2222)    ;; OpenSSH daemon
   (base-feature)))             ;; core tools, symlinks, NTFS, cron GC

(define %vessel (compose-features %vessel-features))
```

### Key Concepts

- **One list, two consumers:** `systems/vessel.scm` and `home/vessel.scm` both import `%vessel`. The system builder filters for `system` and `both` scope features; the home builder filters for `home` and `both`.
- **Order doesn't matter:** Even though `base-feature` is listed last, the topological sort ensures it runs first (since everything else requires it).
- **Parameterization:** `(ssh-feature #:port 2222)` — passing keyword arguments customizes the feature. The ssh feature validates and uses `2222` instead of the default port.
- **`%vessel`:** The composed result. This is what gets passed to `edict-operating-system` and `edict-home-environment`.

### How to customize for another host

Use `modify-features`:

```scheme
(define %laptop-features
  (modify-features %vessel-features
    '(delete nvidia)                              ;; laptop has AMD GPU
    `(replace ssh ,(ssh-feature #:port 22))       ;; standard port
    `(append ,(laptop-power-feature))))           ;; add something new
```

---

## 10. `modules/edict/systems/vessel.scm`

**What it is:** The operating system declaration for the "vessel" machine. Notice how small it is — because all reusable logic is in features.

### The Code

```scheme
(define-module (edict systems vessel)
  #:use-module (edict hosts vessel))  ;; imports %vessel

(edict-operating-system %vessel

  (host-name "vessel")
  (timezone  %timezone)
  (locale    %locale)
  (keyboard-layout %vessel-keyboard-layout)

  (bootloader
   (bootloader-configuration
    (bootloader grub-efi-bootloader)
    (targets '("/boot/efi"))
    (keyboard-layout %vessel-keyboard-layout)))

  (file-systems
   (cons*
    (file-system
     (device (uuid "726825b4-7c05-4909-81d2-abdd71548019" 'ext4))
     (mount-point "/")
     (type "ext4"))
    (file-system
     (device (uuid "3DA9-349D" 'fat32))
     (mount-point "/boot/efi")
     (type "vfat"))
    %base-file-systems)))
```

### Key Concepts

- **Hardware-specific only:** This file declares only what is unique to *this* machine — hostname, bootloader, disk UUIDs. Everything else (packages, services, kernel) comes from `%vessel`.
- **`cons*`:** Like `cons` but chains multiple elements. It prepends the root and EFI partitions to `%base-file-systems` (which includes `/dev/shm`, `/tmp`, etc.).
- **`uuid`:** A Guix procedure that creates a file-system device specification from a UUID. The second argument (`'ext4`) specifies the filesystem type for the UUID lookup.
- **Keyboard layout defined once:** `%vessel-keyboard-layout` is defined locally and reused in both the OS and bootloader config.

### The full picture

When you run `make system`:
1. Guix loads this file
2. `(edict-operating-system %vessel ...)` expands into a full `operating-system` record
3. The builder extracts all packages, services, kernel args, etc. from `%vessel`
4. The hardware-specific fields (bootloader, file-systems) override the auto-wired values
5. Guix builds the system generation and switches to it

---

## 11. `modules/edict/home/vessel.scm`

**What it is:** The home environment (user-level config) for "vessel".

### The Code

```scheme
(define-module (edict home vessel)
  #:use-module (edict hosts vessel))

(edict-home-environment %vessel)
```

### Key Concepts

- **That's it.** Two lines. The same `%vessel` composed features are reused. The home builder filters out system-scope features and extracts only `home-packages-target` and `home-services-target` contributions.
- **Extensible:** If you need vessel-specific home config (dotfiles, environment variables), you add them as additional `home-environment` fields below the macro call.
- **Guix Home:** Manages user-level packages, dotfiles, systemd user services, XDG config, etc. Separate from the system so you can reconfigure your user environment without `sudo`.

---

## Summary: The Data Flow

```
channels.scm          →  guix pull (gets packages)
                              ↓
Makefile              →  guix system reconfigure -L modules/ .../systems/vessel.scm
                              ↓
systems/vessel.scm    →  imports %vessel from hosts/vessel.scm
                              ↓
hosts/vessel.scm      →  list of features → compose-features → %vessel
                              ↓
features/*.scm        →  each feature declares requires/provides/values/extensions
                              ↓
features.scm          →  topological sort → merge values → collect extensions
                              ↓
build.scm             →  edict-operating-system %vessel → operating-system record
                              ↓
Guix                  →  builds and activates the system
```

## Adding Your Own Feature — Quick Recipe

1. Create `modules/edict/features/my-feature.scm`:

```scheme
(define-module (edict features my-feature)
  #:use-module (edict features)
  #:export (my-feature))

(define* (my-feature #:key (enabled? #t))
  (ensure-pred boolean? enabled?)
  (edict-feature
   #:name 'my-feature
   #:provides '(my-feature)
   #:requires '(base)
   #:scope 'system
   #:extensions
   (list
    (contribute system-packages-target "my-package")
    (contribute system-services-target
     (service my-service-type (my-config (enabled? enabled?)))))))
```

2. Add it to `hosts/vessel.scm`:

```scheme
(define %vessel-features
  (list ... (my-feature #:enabled? #f)))  ;; order doesn't matter!
```

3. Run `make system`.

---

## Further Reading

- `docs/01-scheme-crash-course.org` — Learn Scheme syntax in 5 minutes
- `docs/02-edict-architecture.org` — The Lego block analogy for features
- `docs/03-guix-basics.org` — Guix concepts and the Edict workflow
