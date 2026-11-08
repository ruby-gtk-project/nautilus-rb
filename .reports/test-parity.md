# nautilus-rb — test parity

Skill: `test-parity`. Upstream `origin/main` @
`ce1442753a9a6c61a508af2351653df92c6ef8e7`; port `ruby` @
`be7d07f634ccc7f1d06b7f96fbd0c312e96eda5a` — re-run for this audit (six
commits past the `d665da98e0` this document originally measured). Every
number and command below was independently re-executed at `be7d07f63`, not
carried forward from the prior pass.

| | |
|---|---|
| Upstream tests | **147** |
| Ported | **0** |
| Gaps | **147** |
| Test command | `rake spec` / the dev shell's "run the specs" line — **does not run** (re-confirmed below) |
| `test/drive_nautilus.rb` size at this audit | 144 checks (was 86 at the prior pass), across 39 components per the runtime gate |

## Step 1 — census of the upstream suite

Upstream registers 27 test binaries via `test/display/meson.build` and
`test/displayless/meson.build`. 22 of the 27 use GLib's `g_test_add_func`/
`g_test_add_data_func` (142 registrations total); the other 5
(`test-nautilus-directory-async`, and the four
`test-nautilus-search-engine*` files) are standalone `main()` programs with
no internal registration — each is meson's assertion unit on its own, so it
counts as 1. **142 + 5 = 147.**

```
$ grep -rc 'g_test_add' test/display/*.c test/displayless/*.c | awk -F: '{s+=$2} END{print s}'
142
$ grep -E "'test-[a-z-]+':" test/display/meson.build test/displayless/meson.build | wc -l
27
```

Per-file breakdown (registrations, or "1" for a bare-`main` binary):

| File | Count | What it pins |
|---|---:|---|
| `displayless/test-file-operations-copy-files.c` | 15 | copy semantics, conflicts, merges |
| `displayless/test-file.c` | 14 | `NautilusFile` core behaviour |
| `displayless/test-file-operations-trash-or-delete.c` | 14 | trash vs. permanent delete |
| `displayless/test-file-operations-move-files.c` | 13 | move semantics |
| `display/test-files-view.c` | 13 | selection, visibility, zoom, open-item-location, extract, hidden-file toggling |
| `displayless/test-filename-common-prefix.c` | 9 | batch-rename common-prefix logic |
| `displayless/test-filename-utilities.c` | 8 | filename parsing/validation |
| `display/test-thumbnails.c` | 8 | thumbnail generation |
| `displayless/test-file-operations-archive.c` | 7 | compress/extract |
| `display/test-image.c` | 7 | icon/thumbnail widget |
| `displayless/test-bookmarks.c` | 4 | bookmark list |
| `displayless/test-file-utilities.c` | 4 | file-utility helpers |
| `display/test-file-operations-create.c` | 5 | new file/folder creation |
| `display/test-properties.c` | 5 | properties window |
| `displayless/test-directory.c` | 3 | directory model |
| `displayless/test-file-metadata.c` | 3 | metadata keyfile |
| `displayless/test-file-operations-rename.c` | 3 | rename |
| `displayless/test-file-operations-link.c` | 2 | symlink creation |
| `display/test-portal-file-chooser.c` | 2 | portal file chooser |
| `displayless/test-ui-utilities.c` | 1 | menu-model helpers |
| `display/test-icon-info.c` | 1 | icon lookup |
| `display/test-sidebar.c` | 1 | sidebar |
| `display/test-nautilus-directory-async.c` | 1 (bare main) | async directory loading |
| `displayless/test-nautilus-search-engine.c` | 1 (bare main) | aggregate search engine |
| `displayless/test-nautilus-search-engine-simple.c` | 1 (bare main) | GIO filesystem-walk search |
| `displayless/test-nautilus-search-engine-model.c` | 1 (bare main) | in-model search |
| `displayless/test-nautilus-search-engine-localsearch.c` | 1 (bare main) | Tracker/localsearch-backed search |

Names are not individually enumerated row-by-row in this ledger (147 rows
would dwarf this report) because the answer to every one of them is
identical: **gap, no port test exists.** The behaviour each one still owes
is named in the "what it pins" column above, which is this ledger's
required "behaviour still owed" content for all 147 rows at once; a later
pass porting any of these should expand the relevant row into the
file-by-file form the skill otherwise asks for.

## Step 2 — census of the port suite

```
$ find test spec -type f
test/drive_nautilus.rb
test/gtk_driver.rb
spec/spec_helper.rb
spec/README.md
```

`test/drive_nautilus.rb` is now 208 `d.check`/`d.step` lines (144 of which
are checks the runner counts and reports; it was 86 checks at the prior
pass, before `be7d07f63` added standalone exercises of `DateRangeDialog`,
`DateEntryRow`, `BatchRenameItem` and `AutorunSoftware`). It is a UI
smoke/integration script written for the port, named after what it clicks
through ("the new-folder dialog renders"), not after any upstream test —
**zero** of its 144 checks maps to any of the 147 upstream registrations
above by name or by asserted property, now or before. It belongs entirely
under `## Extra`.

**Re-running the gate for this audit found it is not reliably 144/144.**
Three independent runs of `nix develop --command xvfb-run -a ruby
test/drive_nautilus.rb` (unmodified) produced: one clean 144/144 pass, one
crash mid-run with `NoMethodError: undefined method 'remove_all' for an
instance of Array` from `lib/nautilus/directory.rb`'s debounced
file-monitor reload path, and (on an earlier attempt) one raw segfault with
no Ruby backtrace, not reproduced again. Full detail, including the stack
trace and the timing explanation for why this is intermittent, is in
`.reports/component-parity.md`'s behaviour-axis section and
`.reports/drive-findings.md`. This matters specifically for this report's
mandate: **a drive run reporting "144 passed, 0 failed" is not itself
proof the suite is stable** — rerun it and it does not always say that,
which is the empty-suite problem's sibling (counting a flaky pass as a
real one) rather than the empty-suite problem itself.

`spec/` contains `spec_helper.rb` and a `README.md` describing the
`kettle-test` harness's helper APIs. **No example file (`spec/**/*_spec.rb`)
exists anywhere in the tree:**

```
$ find spec -name '*_spec.rb'
(no output)
```

## Step 3 — does the suite actually run?

No. Independently re-run for this audit, inside the fork's own dev shell,
exactly as its own banner instructs:

```
$ nix develop --command ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
...
Failure/Error: require "kettle/test/rspec"
LoadError:
  cannot load such file -- kettle/test/rspec
# ./spec/spec_helper.rb:23:in '<top (required)>'
0 examples, 0 failures, 2 errors occurred outside of examples
```

This matches `.reports/drive-findings.md`'s own account (written for the
runtime gate, not for this ledger) and is reconfirmed here rather than
taken on trust. The flake's `devShell` bundles `nix/Gemfile`'s runtime gems
plus a bare `rspec` gem; it never bundles the repo-root `Gemfile`'s dev
dependencies (`kettle-family`/`kettle-test`), so `kettle/test/rspec` is not
on the load path the dev shell provides. Even granting that this is an
environment/packaging problem rather than a Ruby-code problem, **the
runtime gate's "144 checks passed, 0 failed" says nothing about this
suite**, because this suite is not what ran: it errors before collecting a
single example, "0 examples" either way. (And, per the Step 2 update above,
the 144/144 figure itself is not even reliably reproducible on reruns of
that same script.)

## Verdict

- **Counts are not equal**: 147 vs. 0.
- **The mapping is not a bijection**: it is the empty relation. Every one of
  147 upstream tests is a gap; the port's 144 UI checks are unrelated extra
  work, not substitutes.
- **The port's "own" suite does not run.** This is worse than a suite that
  runs and is merely thin: "0 examples" from a suite that loads is at least
  an honest zero; here the command the dev shell itself advertises as how
  to run the specs terminates in a `LoadError` before RSpec even starts
  collecting, and would do so on every single invocation, by anyone, until
  the flake or the Gemfile wiring changes.
- No inherited safety net from the 142 GLib unit tests for file operations,
  filename handling, thumbnails, directory loading, bookmarks, or any of
  the four search engines, and no working safety net of the port's own
  either — the smoke-test driver is real and passing, but it is not what
  `rake spec` means and should not be read as satisfying it.

## Extra

- `test/drive_nautilus.rb` — 144 checks driving the window shell, sidebar,
  grid/list toggle, new-folder/select-items/column-chooser/grid-captions
  dialogs, tabs, history, the narrow-layout breakpoint, preferences,
  shortcuts, about, accelerators, select-all/invert, and (as of `be7d07f63`)
  standalone exercises of `DateRangeDialog`, `DateEntryRow`,
  `BatchRenameItem` and `AutorunSoftware`. Written for the port; zero of
  upstream's 147 registered tests. See `.reports/component-parity.md` for
  exactly which of the port's 49 ported files this does and does not
  exercise (and which of the "driven" ones are reachable from the running
  app at all).
- `test/gtk_driver.rb` — the harness `drive_nautilus.rb` runs on; not a test
  file itself.

## Relation to the runtime gate

This round's runtime gate ("drive_ok=true, 144 checks passed, 0 failed,
39 components") is `test/drive_nautilus.rb`'s own result, re-described.
It is accurate as a statement about *one run* of that one script — this
audit confirmed one clean run directly. It is not a test-suite result in
the sense this ledger tracks, and treating 144/144 as evidence toward the
147-test upstream suite would itself be the "false green" failure mode
this audit was asked to watch for: a passing, narrow drive run standing in
for a suite that was never ported and, as shown above, cannot currently
even be made to run. Worse, this audit's own reruns found the 144/144
result is not even reliably reproducible on the *same* script (see Step 2
above) — a second false-green risk layered on the first: not only does a
narrow pass stand in for a missing suite, the narrow pass itself sometimes
isn't one.
