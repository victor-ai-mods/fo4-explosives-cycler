# Explosives Cycler

Fallout 4 (1.10.163, F4SE) mod: grenade and mine lists (up to 10) defined in JSON.
MCM hotkeys - next / previous list, next / previous item in the current list - or the
reusable "Explosives Cycler" Aid item switch between them round-robin and show
the list's icons and the item, e.g. "(grenade icon)(grenade icon) Fragmentation Grenade MIRV ×5":
`[grenade]`, `[mine]` and `[molotov]` in a list name are drawn as icons. When the equipped explosive runs out, the next one from the same list is
equipped; a picked up item from the current list is equipped when nothing is.

Default lists: weak grenades (ascending damage), strong grenades (descending damage),
weak mines, strong mines, Molotov cocktail. Edit them in
`Data\ExplosivesCycler\lists-user.json` (copy of `lists-default.json`).

Requirements: F4SE (with its scripts), MCM, Garden of Eden Papyrus Extender. DLC optional.
Localisation: English, Russian (MCM, notifications, list names).

Details, build and test protocol (in Russian): [README.ru.md](README.ru.md).
Implementation plan: [PLAN.md](PLAN.md).

License: The Unlicense.
