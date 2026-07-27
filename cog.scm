;;; cog.scm - Forge package manifest for select-ts.hx
;;;
;;; Installable with Steel's package manager:
;;;
;;;   forge pkg install --git https://github.com/waddie/select-ts.hx
;;;
;;; then, in ~/.config/helix/init.scm:
;;;
;;;   (require "select-ts.hx/select-ts.scm")
;;;
;;; Forge copies this directory to ~/.steel/cogs/select-ts.hx/.

(define package-name 'select-ts.hx)
(define version "0.3.0")

;; ts-utils.hx: shared tree-sitter glue, byte<->char conversion.
(define dependencies
  '((#:name "ts-utils.hx"
     #:git-url
     "https://github.com/waddie/ts-utils.hx"
     #:sha
     "654e9cb1909358dad277b24d73833e330e89d1fd")))
