---
type: Reference
title: Open Knowledge Format
description: Google Cloud OKF v0.1 reference used as the structure for the McDuck project wiki.
resource: https://github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf
tags: [reference, okf, markdown, frontmatter, wiki]
timestamp: 2026-06-21T06:44:10Z
---
# Summary

Open Knowledge Format (OKF) is a vendor-neutral format for representing knowledge as a directory of Markdown files with YAML frontmatter. OKF is designed to be readable by humans, parseable by agents, diffable in git, and portable across tools.

# Key Rules Applied Here

* A knowledge bundle is a directory tree of Markdown files.
* Each concept is one `.md` file; the file path is its concept identity.
* Concept documents use YAML frontmatter plus a Markdown body.
* `type` is the only required frontmatter field for concept files.
* Recommended fields include `title`, `description`, `resource`, `tags`, and `timestamp`.
* `index.md` is reserved for directory listings and progressive disclosure.
* `log.md` is reserved for chronological update history.
* Concept relationships are expressed with standard Markdown links.
* Consumers should tolerate unknown types, unknown fields, missing optional fields, and broken links.

# McDuck Adaptation

McDuck uses OKF to organize software-project knowledge rather than data-catalog knowledge. The local concept types include:

* `Project`
* `Architecture`
* `Module`
* `Project Workstream`
* `Progress Report`
* `Decision`
* `Retrospective`
* `Runbook`
* `Reference`
* `Template`

# Citations

[1] [Google Cloud Blog: How the Open Knowledge Format can improve data sharing](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing?hl=en)
[2] [Open Knowledge Format v0.1 Specification](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md)
[3] [Open Knowledge Format repository](https://github.com/GoogleCloudPlatform/knowledge-catalog/tree/main/okf)
