# Review harness portability correction

The final isolated-package gate found a real defect in the review harness:
`city_review_progression.gd` completed its ten assertions, then attempted to
write beneath `res://artifacts`. That directory was available in the source
checkout but absent from the exported package. The null file handle raised a
script error after the apparent pass. The strict gate correctly rejected it.

The same automatic write existed in four independently authored review scripts.
Only those test scripts were changed; no runtime or gameplay assertion changed:

- `city_review_progression.gd`: 10 assertions.
- `city_review_food_rain.gd`: 9 assertions.
- `city_review_food_revision.gd`: 11 assertions.
- `city_review_skin_catalog.gd`: 212 assertions.

Reports now default to the completion marker on stdout. An optional
`--report=/absolute/filesystem/path.json` writes a file; `--output=` is accepted
as an alias. Relative paths and resource URIs are rejected. Open and flush
errors produce an explicit engine error and a failing process exit rather than
dereferencing a null handle. Game/model cleanup happens before reporting, and
the progression fixture removes its isolated save, temporary file and migration
backup before any optional report-write error can occur.

Original source text is not guaranteed to be present in a compiled PCK.
Unavailable source digests now appear as JSON `null` with an explicit note;
the release gate separately records the actual package digest. An empty string
is no longer presented as a usable source identity.

Author verification ran all four source scripts through the actual
`tools/release_web.py` acceptance and engine-error rules, with explicit absolute
reports. All **242 assertions** passed; each saved report matched the parsed
stdout result, with no unexpected engine errors. Exact script hashes and logs
are in `artifacts/audit-fixes-20260928/review-portability/source/`.
The separate skin agent independently passed the same **242 assertions** from
the isolated PCK directory. It also verified explicit absolute report output
and rejection of missing-parent, relative and resource-URI output paths with
clear errors and no uncaught script error. The gameplay assertion statements
were confirmed byte-identical to the pre-repair scripts. Its independent report
is `docs/fixes/reviews/review-harness-portability.md`, with evidence under
`artifacts/fixes-20260928/reviews/isolated-pck/`.
