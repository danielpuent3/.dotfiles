---
name: pr-review
description: review pull requests end to end; use when asked to "review pr", "review pull request", or similar phrasing
---

# IMPORTANT

- Never attribute feedback to the assistant. Present findings as feedback for the user to send or apply.

# Steps to Review a PR

## Scope and Defaults

- If no URL or PR number is provided, assume the current branch PR.
- Follow `AGENTS.md` policy while reviewing and prioritize security, privacy, auth, payment, and data-integrity risks.
- Use this for broad PR review and feedback drafting. For Copilot-comment triage, use `address-copilot-review`. For branch readiness gates, use `ready-for-review`.

## Review Workflow

1. Read the PR description for intent and scope.
2. Read code changes with focus on behavior, regressions, test coverage, and security impact.
3. Read existing PR comments and replies to avoid duplicating already-settled points.
4. Prepare a response for the user that includes:
   - A concise summary of the PR.
   - Outstanding concerns not fully addressed in existing comments.
   - New suggestions not already covered in PR discussion.
5. Ask the user which points they want to post or act on before publishing responses.

## Response Style Workflow

- When drafting reply text for the user to post, keep it human and conversational.
- Use lowercase style if requested by the user.
- Avoid formal or overly robotic phrasing.
- Do not use em dashes.
- Prefer line comments on specific code when that is clearer than a general thread comment.

## Review Checklist

Apply these checks to all modified code during review:

1. **Naming**: flag abbreviated or ambiguous names; require fully spelled-out clarity.
2. **Structure**: flag excessive nesting; prefer guard clauses and early returns.
3. **Dead code**: remove unused logic, imports, and stale paths.
4. **Security**: check for SQL injection, XSS, CSRF, and sensitive-data leakage.
5. **Performance**: check for N+1 queries and obvious inefficient patterns.
6. **Route coverage**: new routes must have matching test coverage.
7. **Exceptions**: prefer that new manually thrown exceptions extend `App\Exceptions\ContextException`.
8. **Migration safety**: new schema changes must have `hasTable()`/`hasColumn()` guards with early return.
9. **Style**: enforce `if (!$correct)` bang operator spacing.

## Validation

- For concerns flagged as bugs, include concrete impact and a proposed fix direction.
- For style-only suggestions, mark as optional unless repository policy requires change.
