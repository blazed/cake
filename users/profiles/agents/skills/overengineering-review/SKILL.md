---
name: overengineering-review
description: Review code only for unnecessary complexity and over-engineering.
disable-model-invocation: true
---

# Review

Do not modify files.

Review the requested diff, files, or codebase only for unnecessary complexity.

Look for:
- code that can be deleted;
- custom implementations replaceable by stdlib or native platform features;
- unnecessary dependencies;
- speculative abstractions or configuration;
- duplicated helpers or layers;
- flexibility with no demonstrated use.

Do not perform a general correctness review unless needed to justify a simplification.

Report each finding concisely:

`path:line — what to remove or simplify → what replaces it`

If nothing meaningful should be simplified, say so.
