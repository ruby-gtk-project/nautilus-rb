# nautilus-rb — translation parity

Skill: `translation-parity`. Upstream `origin/main` @
`ce1442753a9a6c61a508af2351653df92c6ef8e7`; port `ruby` @
`be7d07f634ccc7f1d06b7f96fbd0c312e96eda5a` (six commits past the
`d665da98e0` this document originally measured). Re-run for this audit:
`grep -rn '_(\|N_(\|C_('  lib/ exe/` is still empty and no `po/` directory
exists anywhere in the tree. Nothing changed on this axis between the two
commits — none of the six files added since the prior pass marks any
string for translation either — so the verdict and every number below are
unchanged and were independently reconfirmed, not carried forward.

| | |
|---|---|
| Upstream msgids (sample catalogue, `po/de.po`) | ~1,180 (incl. 92 plural pairs, 83 with `msgctxt`) |
| Upstream languages (`po/LINGUAS`) | 132 |
| Upstream `.po` files present at this commit | 124 |
| `po/POTFILES.in` entries (files that carry translatable strings) | 114 |
| Port `_()`/`N_()`/`C_()`/gettext calls anywhere in `lib/` or `exe/` | **0** |
| Port `po/` directory | **does not exist** |
| Port `.mo` files shipped, any language | **0** |

## Step 1 — the key sets

Upstream's key set cannot be matched against the port's because the port
has no key set at all:

```
$ grep -rn '_(\|N_(\|C_(' lib/ exe/
(no output)
$ find . -iname '*.po' -o -iname '*.pot' -o -type d -iname 'po'
(no output, outside .git)
```

Every one of upstream's ~1,180 msgids (`po/de.po` used as the
representative count; `POTFILES.in` lists 114 files total, so the real
en-US source count is at least that, likely somewhat higher once plurals
are unfolded) is unmatched. **0 of ~1,180+ keys survive.** This is not a
rewording or a moved-string problem to diff line by line — there is
nothing on the port side to diff against.

## Step 2 — byte-identical keys

Not reached. A byte-identity check presupposes a candidate key on the port
side to compare. None exists.

## Step 3 — the languages

```
$ wc -l < <(git show origin/main:po/LINGUAS | tr ' ' '\n' | grep -v '^$')
132
```

132 languages ship upstream (124 `.po` files present in this tree
snapshot — a handful of `LINGUAS` entries may be newly added without a
corresponding file yet checked in, not investigated further since it does
not change the finding below). The port ships **0**. Every user who runs
GNOME in anything but English loses 100% of this app's interface text the
moment they run the port instead of upstream — not "loses nuance," loses
the strings outright, because the port's widgets are built with Ruby
string literals, in English, with no translation layer wrapping any of
them.

## Step 4 — a sample of what is lost, read from the port source directly

Picked at random while reading `lib/` for the other four reports, none of
these carries any translation marker:

```
$ grep -n "'_Rename'\|'Rename'" lib/nautilus/rename_file_popover.rb
$ grep -n "label:" lib/nautilus/files_view.rb | head -3
```
(spot-checked interactively; `files_view.rb`'s context-menu `label:` values
— `'Open'`, `'Open With Other Application'`, `'Cut'`, `'_Copy'`,
`'Properties'`, etc. — and `preferences_dialog.rb`'s group/row titles are
all plain Ruby string literals.)

This is not a nitpick about one label: it is the condition of **the entire
port**, because the finding in Step 1 ("0 gettext calls in the whole tree")
already covers every file. There is no file this audit found that is an
exception.

## Verdict

Translation parity fails completely and uniformly:

1. Key sets: 0 of upstream's msgids survive, because none were ever marked
   as translatable in the port.
2. Byte-identity: not applicable — there is no port-side key to be
   identical or different to.
3. Languages: 132 upstream languages, 0 shipped by the port.

This is the starkest of the five reports in this audit because it has no
partial credit to award: `component-parity` found 49 of 73 components
built, `test-parity` found 0 of 147 upstream tests but at least a real
smoke-test suite on the port's own side. Here there is no comparable
partial state — the port is translated into exactly one language, English,
project-wide, and every widget built so far (including the 49 "ported"
components `component-parity` otherwise credits) fails this axis
individually, per that skill's rule that a component can pass the other
three axes and still fail this one.

## What would closing this require

Per the skill, this is `po/` plus a marking pass plus a runtime gettext
binding — none of which is a per-widget fix. It needs:

- Adding a gettext call (likely the `gettext` or `fast_gettext` Ruby gem —
  not yet in `nix/Gemfile`) wired into the app's startup, matching
  upstream's text domain.
- Marking every user-visible string already written in `lib/`/`exe/` with
  `_()` (or `n_()` for the plural cases — plural forms exist upstream,
  e.g. the 92 `msgid_plural` entries sampled from `de.po`), using
  **upstream's existing English msgids verbatim**, not restating them,
  since a reworded string is a new, untranslated key under the rule in
  the `component-parity` skill this report's sibling applies per-component.
  This audit found no evidence any string was copied with that
  byte-for-byte discipline, because no string in the port carries a marker
  to check it against.
- Copying `po/LINGUAS` and all 124+ `.po` files from upstream unchanged,
  and wiring a `.mo` build step the packaging (`flake.nix`/`nix/Gemfile`)
  currently has no equivalent of.

None of this exists yet, in any amount.
