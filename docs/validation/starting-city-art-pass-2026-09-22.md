# Starting City art pass

This preview is a separate art study for the first-floor Starting City. It composes the existing
modular house and prop library with a new procedural Black Iron Palace, market and smithy dressing,
street lanterns, plaza trees, gate signage and four original primitive residents.

The residents use explicit hand sockets and a small generated loadout catalogue: sword, dagger,
spear, axe, hammer, shield, bow, lantern, potion, book and bag. The same socket API can later be
fed by authoritative inventory and equipment state; this preview currently has no save access,
model calls or world mutation.

The reference pass uses broad published motifs: the Town of Beginnings sits at the southern end of
the first floor, its central plaza is associated with the Black Iron Palace, and the wider floor
opens toward western forest, northeastern lake/wetland, eastern ruins and a northern labyrinth
approach. The implementation is an original proportional dressing study, not a claim of exact
canon geography.

Run the structural check from the repository root:

```text
godot --headless --path game --script res://tests/starting_city_art_acceptance.gd
```

The accepted baseline records at least 46 imported asset instances, 53 procedural asset instances,
five landmark collision bodies, four loadout residents, zero model calls and zero world mutations.
Headless Godot cannot save a renderer screenshot with the dummy display driver; the preview exposes
an optional `--capture-dir=` argument for a desktop or compatibility-renderer run.
