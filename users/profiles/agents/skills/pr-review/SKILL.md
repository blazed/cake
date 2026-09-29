---
name: pr-review
description: "Review GitHub pull requests interactively with gh and jj, then post one batched review after approval. Use when asked to review a PR, check my PRs, or help with code review."
---

# PR Review

Interactive review of a GitHub pull request. Nothing is posted until the user approves the plan.

## Step 1: Find the PR

If the user named a PR, use it. Otherwise list open PRs where the user is assigned, requested, or has already reviewed:

```bash
gh pr list \
  --search "is:open (review-requested:@me OR reviewed-by:@me OR assignee:@me)" \
  --limit 10 \
  --json number,title,author,createdAt \
  --jq '.[] | "#\(.number) \(.title) (\(.author.login), \(.createdAt[:10]))"'
```

Present the results as a numbered list and ask which to review. If there is only one, confirm before proceeding.

## Step 2: Gather the PR

```bash
gh pr view <N> --json number,title,body,author,baseRefName,headRefName,headRefOid,isCrossRepository
gh pr diff <N>
gh api repos/{owner}/{repo}/pulls/<N>/comments --jq '.[] | {id, path, line, user: .user.login, body}'
```

`gh api` fills in `{owner}` and `{repo}` from the current repository. Keep `headRefOid` — every comment is anchored to it.

To read full files at the PR head without touching the working copy (same-repository PRs only):

```bash
jj git fetch --branch <headRefName>
jj file show -r '<headRefName>@origin' <path>
```

Do not use `gh pr checkout`; it moves Git's HEAD behind JJ. If the user wants to run the code, use `jj new '<headRefName>@origin'` and return with `jj edit` afterwards. For cross-repository PRs, review from `gh pr diff` and `gh pr view` only.

## Step 3: Analyze the changes

**High-level summary**

- Overall purpose of the PR
- New APIs (endpoints, functions, methods), data structures, and configuration
- New dependencies, schema or migration changes, breaking changes
- Architectural or design-pattern changes

**Dependency check**

- New dependencies: actively maintained? Archived or deprecated?
- Could an existing dependency or code already in the repository do the job?

**Impact assessment**

- What existing code is affected, and what needs to know about the change?
- Documentation implications

## Step 4: Review focus areas

A numbered list of files or directories in review order: foundational changes first, then core logic, then usages, then tests. For each, note what to focus on: API/schema design, complex logic, edge cases and error handling, performance, security, test gaps, consistency.

## Step 5: Suggested comments

List suggested comments grouped by file and ordered by line ascending. For each:

- Casual, lowercase, short ("consider...", "might be worth...", "nit: ...").
- Strongly worded only for an obvious bug.
- Anchored to a line **that appears in the diff** at `headRefOid`; comments on lines outside the diff are rejected by GitHub. Verify against `gh pr diff` or `jj file show`.

Format as plain text, not code blocks:

`path:line` — comment

Then propose a verdict: `APPROVE`, `COMMENT`, or `REQUEST_CHANGES`, with a 1–2 sentence review body. GitHub does not allow approving or requesting changes on your own PR; use `COMMENT` there.

**Stop here and wait for the user.** They may edit, drop, or add comments, or change the verdict.

## Step 6: Post the review (only after approval)

Post everything as **one** review. Write the payload to a temporary file:

```json
{
  "commit_id": "<headRefOid>",
  "event": "COMMENT",
  "body": "short summary",
  "comments": [
    { "path": "src/lib.rs", "line": 42, "side": "RIGHT", "body": "nit: ..." },
    { "path": "src/lib.rs", "start_line": 50, "line": 55, "side": "RIGHT", "body": "consider ..." }
  ]
}
```

```bash
gh api repos/{owner}/{repo}/pulls/<N>/reviews --method POST --input review.json
```

- `side` is `RIGHT` for added/unchanged lines and `LEFT` for deleted lines.
- Use `start_line` + `line` for multi-line comments.
- `body` is required for `COMMENT` and `REQUEST_CHANGES`.
- Do not create a pending review first and add comments to it via `/pulls/<N>/comments`; that endpoint publishes comments individually and fails with 422 while a pending review exists.

Replies to existing threads are posted immediately and separately, so include them in the approved plan too:

```bash
gh api repos/{owner}/{repo}/pulls/<N>/comments/<comment_id>/replies -f body="<reply>"
```

Report the review URL from the response (`html_url`) when done.
