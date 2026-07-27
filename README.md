# select-ts.hx

Run an ad hoc tree-sitter query and select every node it captures, for Helix.

Helix ships fixed `textobject` queries. These commands accept an arbitrary
query and turn each captured node into a range in the selection, so

```scheme
(function_item) @f
```

puts a cursor on every function in the buffer.

- `:select_ts` – prompt for a query and select the matches.
- `:select_ts_repeat` – re-run the last query that matched, without prompting.
- `:select_ts_query <query>` – run a query given directly, for keymaps.

## Conventions

**`@select` wins.** A query that captures `@select` yields only those nodes, so
other captures can exist purely to drive predicates:

```scheme
((identifier) @select (#match? @select "^is_"))
```

A query without `@select` yields every capture, which is what makes the one
capture case short.

**The selection is the scope.** When the selection covers more than a bare
cursor, the query runs inside it, one pass per range, narrowing the selection;
otherwise it runs over the whole document.

## Install

Install with Forge:

```sh
forge pkg install --git https://github.com/waddie/select-ts.hx
```

Then in `~/.config/helix/init.scm`:

```scheme
(require "select-ts.hx/select-ts.scm")
```

Optionally bind keys, for example:

```scheme
(keymap (global)
  (normal (space (B (q ":select_ts")
                    (r ":select_ts_repeat")
                    (f ":select_ts_query (function_item) @f")))))
```

You can also create your functions that call `select_ts`, allowing you to add
your own doc string. e.g.

```scheme
;;@doc
;; Select every Go function name in the buffer: plain funcs, receiver methods,
;; and interface method declarations.
(define (select_ts_go_fns)
  (select_ts_query
    "[ (function_declaration name: (identifier) @select)
       (method_declaration name: (field_identifier) @select)
       (method_elem name: (field_identifier) @select) ]"))

(keymap (global)
  (normal
    (space (B (g ":select_ts_go_fns"))))
  (select
    (space (B (g ":select_ts_go_fns")))))
```

![Selecting all function names in Helix with a tree-sitter query](https://github.com/waddie/select-ts.hx/blob/main/images/select-ts.gif?raw=true)

Queries can test structure as well as content. tree-sitter has no way to say
“not a child of X”, but a doubled wildcard effectively says the same thing: a node
with both a parent and a grandparent cannot be at the top of the file. That is
enough to pick out inline lambdas and leave top-level definitions alone. The
third pattern here needs no such test: a `letfn` binding looks like any other call
on its own, so it is found by its position after the `letfn` symbol, which puts it
below the top level by construction:

```scheme
;;@doc
;; Select every Clojure lambda below the top level: (fn ...), (fn* ...) and
;; #(...) nested at any depth, plus letfn bindings, skipping any written at the
;; top of the file.
(define (select_ts_clj_lambdas)
  (select_ts_query
    "(_ (_ (list_lit . (sym_lit) @_op) @select) (#any-of? @_op \"fn\" \"fn*\"))
     (_ (_ (anon_fn_lit) @select))
     (list_lit . (sym_lit) @_letfn . (vec_lit (list_lit) @select)
       (#eq? @_letfn \"letfn\"))"))
```

## Notes

Overlapping captures collapse. Helix normalises a selection by sorting and
merging overlapping ranges, so a query capturing both a node and something
inside it produces one range, not two. The status line reports both counts when
they differ.

The builtin prompt has no history and takes no initial value, hence
`:select_ts_repeat`. The last query is remembered only when it matched.

## License

Copyright © 2026 Tom Waddington

Distributed under the MIT License. See LICENSE file for details.
