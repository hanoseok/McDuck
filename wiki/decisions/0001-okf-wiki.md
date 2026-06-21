---
type: Decision
title: Adopt OKF-style project wiki
description: Maintain McDuck project knowledge as a Markdown plus YAML frontmatter bundle under wiki/.
resource: https://github.com/hanoseok/McDuck/tree/develop/wiki
tags: [decision, okf, wiki, documentation]
timestamp: 2026-06-21T06:44:10Z
status: accepted
---
# Context

McDuck development has project knowledge spread across README, release notes, build docs, GitHub Actions, source code, tests, and chat history. Future agents and humans need a durable place to organize development, progress, and retrospective knowledge without requiring a separate service.

Google's Open Knowledge Format describes a minimal, portable approach: a directory of Markdown files with YAML frontmatter, `index.md` files for progressive disclosure, `log.md` files for chronological updates, and normal Markdown links as concept relationships.

# Decision

Create `wiki/` as an OKF-style knowledge bundle inside the McDuck repository.

# Consequences

* Project knowledge can be versioned and reviewed with code.
* Agents can navigate from `wiki/index.md` into progressively narrower context.
* Decisions, progress notes, module summaries, runbooks, references, and retrospectives get stable homes.
* The wiki should be updated as part of meaningful development work, especially after releases, design decisions, and debugging discoveries.

# Related Concepts

* [Open Knowledge Format](/references/open-knowledge-format.md)
* [Project Overview](/project-overview.md)
* [Initial OKF Wiki Setup Progress](/progress/2026-06-21-okf-wiki-foundation.md)
