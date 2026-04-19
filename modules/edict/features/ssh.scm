;;; Copyright © 2026 hirancph
;;;
;;; ssh.scm — OpenSSH daemon feature.

(define-module (edict features ssh)
  #:use-module (gnu services)
  #:use-module (gnu services ssh)
  #:use-module (gnu packages ssh)
  #:use-module (edict features)
  #:export (ssh-feature))

(define* (ssh-feature #:key
                      (port 2222)
                      (permit-root-login? #f)
                      (password-auth? #t))
  "OpenSSH daemon with configurable port and security settings.
PORT defaults to 2222 to avoid bots scanning the default 22.
System-scope only."

  ;; ── Validation ──
  (ensure-pred integer? port)
  (ensure-pred boolean? permit-root-login?)
  (ensure-pred boolean? password-auth?)

  (edict-feature
   #:name 'ssh
   #:provides '(ssh)
   #:requires '(networking)
   #:scope 'system
   #:values `((ssh-port . ,port))
   #:extensions
   (list
    (contribute system-services-target
     (service openssh-service-type
              (openssh-configuration
               (openssh openssh-sans-x)
               (port-number port)
               (permit-root-login (if permit-root-login? #t #f))
               (allow-empty-passwords? #f)
               (password-authentication? password-auth?)))))))
