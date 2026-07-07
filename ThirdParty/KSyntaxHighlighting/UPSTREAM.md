# KSyntaxHighlighting vendor subset

This repository vendors KDE KSyntaxHighlighting XML definitions as the first
source of truth for the plain-editor syntax import path.

Pinned upstream snapshot:

- commit: `12091c2350d9bd131246bb0fd98fae1c5bde560f`

Current vendored collection:

- all `data/syntax/*.xml` files from the pinned upstream snapshot

Import policy:

- the full ruleset source is KDE KSyntaxHighlighting XML under `data/syntax/`
- keep a pinned, reviewable import path instead of an untracked live fetch
- refresh by replacing the vendored snapshot with a new pinned upstream commit

License notes:

- preserve each file's embedded copyright and license metadata
- the vendored files are mixed-license by file, so do not assume a single upstream license
- keep third-party notices in `THIRD_PARTY_NOTICES.md`
