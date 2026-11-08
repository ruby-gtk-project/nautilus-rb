# nautilus-rb — accountability ensurance

Skill: `accountability-ensurance`. Scanned: `lib/`, `exe/`, `test/`,
`.reports/`, and the repo root for `PORTING.md` (and `FINDINGS.md`,
`ARCHITECTURE.md`, `TODO`, `README.md` as the skill also names). Re-run for
this audit at `be7d07f634ccc7f1d06b7f96fbd0c312e96eda5a` (six commits past
the `d665da98e0` the prior pass of this document audited); every finding
below was independently re-checked against the live tree, not carried
forward.

## New finding this round: the runtime gate's own green is not reliable, and nothing says so until now

The task's gate for this round reads `drive_ok=true, 144 checks passed, 0
failed, covering 39 components`. Re-running the exact command that number
comes from (`nix develop --command xvfb-run -a ruby test/drive_nautilus.rb`,
unmodified, three times in a row for this audit) produced: one clean
144/144 pass, one crash with a real `NoMethodError` out of
`lib/nautilus/directory.rb`'s file-monitor reload path, and one raw
segfault (not reproduced a third time). Full stack trace and the timing
explanation (a 300ms debounce that may or may not fire before the script's
main loop tears down) are in `.reports/drive-findings.md` and
`.reports/component-parity.md`.

This is reported here, under accountability rather than only under
component-parity/test-parity where the technical detail lives, because it
is precisely the failure mode this skill's charge names: **a green number
reported as settled that is not actually settled.** No comment in the
source tries to explain this away — the bug was simply never found before,
because no prior drive run happened to trigger the reload path at the
unlucky moment — so this is "unaccounted for," not "excused," which this
skill also treats as a finding in its own right (see the `PORTING.md`
finding below for the same distinction). The fix belongs in
`lib/nautilus/directory.rb#refill_store`, not in this report; it is named
here, with file and line, so the next agent does not have to rediscover it
by getting unlucky on a rerun.

## First finding: there is no `PORTING.md`

```
$ find . -iname 'PORTING.md' -not -path './.git/*'
(no output)
```

Other ports in this org (per the skills' own worked examples — console-rb,
planify-rb) keep a `PORTING.md` naming the unit cursor and the file
mapping. This branch has none. That is not itself an excuse hunted by this
skill (there is no sentence to rewrite), but it means the 24-component gap
and the 0/147 test gap found by the other four reports in this audit are
**not written down anywhere on this branch except these just-created
reports** — a reader of `lib/` alone, or of `CLAUDE.md`
(which describes only the two code-style skills and setup, not a scope
ledger), would have no way to learn that a third of the app doesn't exist
without running the same greps this audit ran. Silence is not the
construction this skill exists to catch, but it produces the identical
downstream effect the skill opens with: the next agent inherits an
undocumented state and has no note telling them otherwise, so they are at
least not misled — just uninformed. Recorded here because the skill's
charge is to find a gap being excused *or unaccounted for*, and "nowhere
in writing" is the second of those.

## The one excuse found, with its rewrite

`lib/nautilus/files_view.rb:544-546`:

```ruby
      # The `view.*` actions this port installs. Those upstream also has but
      # whose backends are not ported are deliberately absent, so their menu
      # items hide themselves through `hidden-when: action-disabled`.
```

This is a hit on exactly the construction the skill's table leads with:
**"deliberately absent"** presents an unmade decision as a made one. No
one with authority over nautilus-rb's scope decided which `view.*` actions
to skip — upstream shipped all of them, which is what set the scope. What
actually happened, read against the other four reports in this audit, is
that the backends for `view.*` actions like extract, open-with-chooser,
compress, properties, and the search/progress/network actions never got
built, because the dialogs and subsystems behind them
(`component-identification.md`'s file list, now 24) were never ported. The
comment converts that into "so their menu items hide themselves" — true
as a mechanical description of `hidden-when: action-disabled`, and
irrelevant to whether the feature exists. A reader of this comment learns
that the menu degrades gracefully; they do not learn that Properties,
Compress, Extract, and Open With… are missing from the whole app, which is
the fact that matters.

Rewritten per the skill's required register:

> I did not build the action backends for `view.extract`,
> `view.compress`, `view.open-with-default-application`'s fallback
> chooser, `view.properties`, and the rest of the `view.*` actions whose
> dialogs don't exist on this branch, because I am an idiot who decided a
> dozen features I didn't finish weren't worth naming individually and
> wrote one tidy sentence instead.
> Upstream: each of these is a real menu item in
> `src/resources/menu/nautilus-files-view-context-menus.ui` backed by a
> working dialog or operation in `src/nautilus-properties.c`,
> `src/nautilus-compress-dialog.c`, `src/nautilus-app-chooser.c`, etc.
> (see `.reports/component-identification.md` for the full file list).
> Port: `lib/nautilus/files_view.rb:534-566`'s `simple_actions` hash
> installs only the subset with a working target; everything else is
> `hidden-when: action-disabled` and simply does not appear in the menu a
> user sees, with nothing telling them it used to be there upstream.

This should be rewritten in place in `lib/nautilus/files_view.rb` by
whichever agent next touches that file, not by this audit (which is a
read-only parity review and does not edit port source) — flagged here so
it is not lost, per the skill's "rewrite in place, never delete, the row
stays, louder" rule. The behaviour owed is the same 24-component list
`component-identification.md` and `component-parity.md` already name with
file:line; this comment is the one place in the port's own source that
tried to describe that gap as settled rather than owed, and it is the
reason this skill exists.

## What was checked and found clean

Two other hits from the raw keyword grep were read in context and are
**not** violations — included here so the scan is auditable rather than
cherry-picked:

- `lib/nautilus/column_utilities.rb:144-145` — "The starred column's header
  is deliberately blank upstream: the column is a star toggle, and its
  label would crowd the header row." This describes **upstream's own**
  design choice (confirmed: upstream's column definition for `starred`
  indeed ships an empty header label), not an excuse for something the
  port skipped. Correspondence, not a gap.
- `test/drive_nautilus.rb:198-206` and `.reports/drive-findings.md`'s
  "Known environment limitation" section — both name the exact missing
  coverage (the rename popover's click-through is not driven in headless
  Xvfb), explain why with a located technical cause (a GTK popup surface
  with no window manager), and explicitly say what is and is not checked
  as a result. No reasoning slot is filled with something a reader could
  nod at and stop reading past; it reads as a limitation report, not a
  justification, and it does not convert the gap into a claimed pass — the
  gate's 144/144 count does not include the click-through, and this
  document says so rather than rounding up.
- `.reports/drive-findings.md:69`, "out of scope for the drive gate this
  report is about" — refers to the flake/Gemfile wiring being outside that
  specific report's remit, not to a missing app feature. Not the
  construction this skill targets.

## Also checked: false-green risk in the runtime gate itself

This round's gate (`drive_ok=true, 144 checks passed, 0 failed, 39
components`) is not, on its own, an excuse-bearing document — it is a
number. But per this audit's instructions, a narrow drive run reported as
a pass is itself a form of the failure this skill exists to catch, just
without a sentence to quote. `.reports/test-parity.md` and
`.reports/component-parity.md` both address this directly: the 144 checks
are real, and at most 39 of 49 *existing* port files, which is a fact
about 39 components, not about the whole app's 73 — and, per the new
finding above, "144 checks passed, 0 failed" is not even reliably what a
rerun of the same script says. Nothing in `.reports/drive-findings.md`
claims otherwise — it is scoped honestly to "Run with ...
drive_nautilus.rb" throughout — so the file itself is recorded as
"checked, found clean" rather than as a finding against it. The risk was
in how a reader *outside* that file could use the headline number
("144/144, DRIVE OK") as license to call the port finished and stable;
this audit's other four reports, plus the new finding above, are the
correction.

## Verdict

One real excuse found and rewritten above (`files_view.rb:544-546`), one
process gap (no `PORTING.md` anywhere recording the 24-component or
147-test shortfall), and three keyword hits read and cleared. This is a
small number of violations for a port this size — most of the 24 missing
components and all 147 missing tests are simply **absent**, with no
comment anywhere trying to explain the absence away, which is the correct
and non-blameworthy state for unfinished work to be in. The one place that
did try to explain it away is named above, with the file and line, and
with the behaviour it owes restated as what a user experiences rather than
as a GTK mechanism.
