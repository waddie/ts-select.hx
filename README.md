# ts-select.hx

Run an ad hoc tree-sitter query and select every node it captures, for Helix.

Helix ships fixed textobject queries. This takes one you type at a prompt and
turns each captured node into a range in the selection, so

```scheme
(function_item) @f
```

puts a cursor on every function in the buffer and normal multi-cursor editing
takes it from there.

- `:ts-select` – prompt for a query and select the matches.
- `:ts-select-repeat` – re-run the last query that matched, without prompting.
- `:ts-select-query <query>` – run a query given directly, for keymaps.

## Conventions

**`@select` wins.** A query that captures `@select` yields only those nodes, so
other captures can exist purely to drive predicates:

```scheme
((identifier) @select (#match? @select "^is_"))
```

A query without `@select` yields every capture, which is what makes the one
capture case short.

**The selection is the scope.** When the selection covers more than a bare
cursor the query runs inside it, one pass per range; otherwise it runs over the
whole document. Narrowing is a matter of selecting first.

## Install

Install with Forge:

```sh
forge pkg install --git https://github.com/waddie/ts-select.hx
```

Then in `~/.config/helix/init.scm`:

```scheme
(require "ts-select.hx/ts-select.scm")
```

Optionally bind keys, for example:

```scheme
(keymap (global)
  (normal (space (B (q ":ts-select")
                    (r ":ts-select-repeat")
                    (f ":ts-select-query (function_item) @f")))))
```

You can also create your functions that call `ts-select`, allowing you to add
your own doc string. e.g.

```scheme
;;@doc
;; Select every Go function name in the buffer: plain funcs, receiver methods,
;; and interface method declarations.
(define (ts-select-go-fns)
  (ts-select-query
    "[ (function_declaration name: (identifier) @select)
       (method_declaration name: (field_identifier) @select)
       (method_elem name: (field_identifier) @select) ]"))

(keymap (global)
  (normal
    (space (B (g ":ts-select-go-fns"))))
  (select
    (space (B (g ":ts-select-go-fns")))))
```

![Selecting all function names in Helix with a tree-sitter query](https://github.com/waddie/ts-select.hx/blob/main/images/ts-select.gif?raw=true)

## Notes

Overlapping captures collapse. Helix normalises a selection by sorting and
merging overlapping ranges, so a query capturing both a node and something
inside it produces one range, not two. The status line reports both counts when
they differ.

The builtin prompt has no history and takes no initial value, hence
`:ts-select-repeat`. The last query is remembered only when it matched.

## License

Copyright © 2026 Tom Waddington

Distributed under the MIT License. See LICENSE file for details.
