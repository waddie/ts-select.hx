;; ts-select.scm - turn an ad hoc tree-sitter query into a multiple selection.
;;
;; Helix ships fixed textobject queries; this runs one you type. Every node the
;; query captures becomes a range in the selection, so `(function_item) @f` puts
;; a cursor on each function in the buffer and normal multi-cursor editing takes
;; over from there.
;;
;; Two conventions keep the prompt short. A query that captures `@select` yields
;; only those nodes, so scratch captures can exist for predicates; a query
;; without one yields every capture. And when the selection covers more than a
;; bare cursor the query runs inside it rather than over the whole document,
;; which makes narrowing a matter of selecting first.

(require "ts-utils.hx/ts.scm") ; current-doc-id, current-rope, current-language,
; char->byte, node-start-char, node-end-char
(require (only-in "helix/treesitter.scm"
          tsquery-loader
          string->tsquery
          query-document
          query-document-byte-range
          tsmatch-captures
          tsmatch-capture))
(require "helix/static.scm") ; selection / range accessors and setters
(require "helix/misc.scm") ; push-component!, set-status!, set-error!

(provide ts-select
  ts-select-repeat
  ts-select-query)

;; Capture name that, when a query uses it, narrows the result to just its nodes.
(define select-capture "select")

;; Source of the last query that matched, for ts-select-repeat. The builtin
;; `prompt` component takes no initial value and keeps no history, so this is
;; the only way back to a query without retyping it.
(define *last-query* (box #f))

;;@doc
;; Prompt for a tree-sitter query and select every node it captures. Honours the
;; `@select` capture and the current selection as a scope.
(define (ts-select)
  (push-component!
    (prompt "ts query:"
      (lambda (src)
        (if (or (not src) (equal? (trim src) ""))
          void
          (run-query src))))))

;;@doc
;; Re-run the last query that matched, without prompting.
(define (ts-select-repeat)
  (let ([src (unbox *last-query*)])
    (if src
      (run-query src)
      (set-status! "ts-select: no previous query"))))

;;@doc
;; Run a query given directly rather than through the prompt. Variadic so a
;; keymap can pass one unquoted, e.g. ":ts-select-query (function_item) @f";
;; Helix splits typed command arguments on whitespace and queries don't care.
(define (ts-select-query . parts)
  (run-query (string-join parts " ")))

;; Compile, run, select. Every entry point funnels through here so error
;; reporting lives in one place.
(define (run-query src)
  (let ([lang (current-language)])
    (if (not lang)
      (set-error! "ts-select: buffer has no language")
      ;; A malformed query is the common case at a prompt, so report it and
      ;; leave the selection alone rather than letting the error escape.
      (let ([query (with-handler
                    (lambda (err)
                      (set-error! (string-append "ts-select: " (to-string err)))
                      #f)
                    (string->tsquery lang src))])
        (if query
          ;; The spans are wanted twice: to run the query, and to say so when a
          ;; scoped run comes back empty.
          (let ([spans (scope-byte-spans)])
            (select-nodes! (query-nodes query lang spans) src spans))
          void)))))

;; Nodes captured by `query` across `spans`, in no particular order. Helix sorts
;; and merges them when the selection is built.
(define (query-nodes query lang spans)
  (let* ([doc (current-doc-id)]
         ;; The loader is consulted for every layer in range, injections
         ;; included. Returning #f for other languages is what stops, say, a Rust
         ;; query being compiled against the format-args grammar inside a
         ;; println!, which fails the whole run with "invalid node type".
         [loader (tsquery-loader (lambda (l) (if (equal? l lang) query #f)))])
    (if (null? spans)
      (captured-nodes (query-document loader doc))
      (concat
        (map (lambda (span)
              (captured-nodes
                (query-document-byte-range loader doc (car span) (cdr span))))
          spans)))))

;; The nodes a match should contribute: just `@select` when the query uses it,
;; every capture otherwise. A TSMatch groups nodes by capture name only, with no
;; per-match correlation, so this is necessarily a name-level choice.
(define (captured-nodes m)
  (if (not m)
    '()
    (let* ([names (tsmatch-captures m)]
           [wanted (if (member select-capture names) (list select-capture) names)])
      (concat (map (lambda (name) (or (tsmatch-capture m name) '())) wanted)))))

;; Byte spans to query as (start . end) pairs: the current ranges when the
;; selection covers more than a bare cursor, else '() meaning whole document.
(define (scope-byte-spans)
  (let ([ranges (selection->ranges (current-selection-object))])
    (if (spans-more-than-cursor? ranges)
      (let ([rope (current-rope)])
        (map (lambda (r) (cons (char->byte rope (range->from r))
                          (char->byte rope (range->to r))))
          ranges))
      '())))

;; A Helix cursor is a one-char range, so anything wider counts as a deliberate
;; selection worth scoping to.
(define (spans-more-than-cursor? ranges)
  (cond
    [(null? ranges) #f]
    [(> (- (range->to (car ranges)) (range->from (car ranges))) 1) #t]
    [else (spans-more-than-cursor? (cdr ranges))]))

;; Replace the selection with one forward range per node. Selection::push sorts
;; by start and merges overlaps, so nested captures collapse into one range and
;; the reported counts can differ.
(define (select-nodes! nodes src spans)
  (if (null? nodes)
    (set-status! (empty-summary spans))
    (let* ([rope (current-rope)]
           [ranges (map (lambda (n)
                         (range (node-start-char rope n) (node-end-char rope n)))
                    nodes)])
      (set-current-selection-object! (range->selection (car ranges)))
      (for-each push-range-to-selection! (cdr ranges))
      (set-box! *last-query* src)
      (set-status! (match-summary (length ranges))))))

;; "no matches", naming the scope when there was one: an empty result from a
;; scoped run usually means the selection was too narrow, not that the query was
;; wrong. Only reached when every span came back empty, so it never claims the
;; whole selection missed when part of it matched.
(define (empty-summary spans)
  (string-append "ts-select: no matches"
    (if (null? spans)
      ""
      (string-append " in " (count-of (length spans) "selection" "selections")))))

;; "N matches", or "N matches (M selections)" when merging collapsed some.
(define (match-summary matched)
  (let ([selected (length (selection->ranges (current-selection-object)))])
    (string-append "ts-select: " (count-of matched "match" "matches")
      (if (= matched selected)
        ""
        (string-append " (" (count-of selected "selection" "selections") ")")))))

;; Append every list in `lists`. Not `apply append`: the argument count would be
;; the number of selection ranges, which is unbounded.
(define (concat lists)
  (let loop ([todo lists] [acc '()])
    (if (null? todo)
      (reverse acc)
      (loop (cdr todo)
        (let inner ([xs (car todo)] [acc acc])
          (if (null? xs)
            acc
            (inner (cdr xs) (cons (car xs) acc))))))))

(define (count-of n singular plural)
  (string-append (to-string n) " " (if (= n 1) singular plural)))
