;;; cog.scm - Forge package manifest for ts-select.hx
;;;
;;; Installable with Steel's package manager:
;;;
;;;   forge pkg install --git https://github.com/waddie/ts-select.hx
;;;
;;; then, in ~/.config/helix/init.scm:
;;;
;;;   (require "ts-select.hx/ts-select.scm")
;;;
;;; Forge copies this directory to ~/.steel/cogs/ts-select.hx/.

(define package-name 'ts-select.hx)
(define version "0.1.0")

;; ts-utils.hx: shared tree-sitter glue, byte<->char conversion.
(define dependencies
  '((#:name "ts-utils.hx"
     #:git-url
     "https://github.com/waddie/ts-utils.hx"
     #:sha
     "654e9cb1909358dad277b24d73833e330e89d1fd")))
