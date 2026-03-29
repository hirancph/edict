;;; channels.scm — Channel definitions for `guix pull`
;;;
;;; Symlink or copy this file to ~/.config/guix/channels.scm
;;;
;;; To add a new channel:
;;;   1. Add a (channel ...) form below
;;;   2. Place any signing keys in channels/

(list
 ;; Official GNU Guix channel
 (channel
  (name 'guix)
  (url "https://git.savannah.gnu.org/git/guix.git")
  (introduction
   (make-channel-introduction
    "9edb3f66fd807b096b48283debdcddccfea34bad"
    (openpgp-fingerprint
     "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))

 ;; Nonguix — nonfree packages (linux kernel, drivers, etc.)
 ;; Uncomment when ready:
 ;; (channel
 ;;  (name 'nonguix)
 ;;  (url "https://gitlab.com/nonguix/nonguix")
 ;;  (introduction
 ;;   (make-channel-introduction
 ;;    "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
 ;;    (openpgp-fingerprint
 ;;     "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))
 )
