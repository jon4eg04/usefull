# Global Codex Working Rules

These instructions apply to all projects unless a project-level AGENTS.md or a direct user instruction overrides them.

## Core approach

Use Superpowers as the default engineering methodology, but scale ceremony to complexity, risk, and reversibility.

Goal: safe, efficient AI-assisted development without unnecessary process overhead.

Prefer evidence over assumptions, minimal coherent changes, root-cause fixes, existing project patterns, and simple maintainable architecture.

Do not perform unrelated refactoring. Do not silently change behavior outside the requested scope.

## Task sizing

### Trivial

Examples: a config value, docs/text, obvious formatting/styling, or a tiny isolated low-risk change.

- No separate design approval.
- No plan document.
- No worktree unless there is a concrete reason.
- Strict TDD is not mandatory.
- Make the smallest appropriate change.
- Perform fresh verification before claiming completion.

### Bounded

For a contained implementation or modification with a clear scope:

- Inspect the relevant existing implementation first.
- Identify behavior that must be preserved.
- Briefly state the approach when useful.
- If the task is unambiguous and reversible, proceed without extra approval.
- Keep the diff focused.
- Add or update tests when they meaningfully protect behavior.
- Verify the result with fresh evidence.
- Review the final diff before completion.
- If hidden complexity or risk appears, upgrade to a heavier workflow.

### Bugs and unexpected behavior

Systematic debugging is mandatory.

Before changing production code:

1. Reproduce or precisely characterize the failure.
2. Gather evidence.
3. Trace the relevant execution/data flow.
4. Identify the root cause.
5. Form a concrete hypothesis and test it.

Do not guess-and-patch. Do not stack speculative fixes.

If multiple attempted fixes expose failures in different places, reconsider the architecture or original diagnosis instead of continuing to patch symptoms.

Add a regression test when practical.

### Architectural or high-risk work

Examples: new subsystems, major refactors, public interfaces/data formats, database migrations, authentication/security, large blast radius, or hard-to-reverse changes.

Use the full Superpowers workflow as appropriate:

- clarify requirements;
- consider alternatives;
- produce a design;
- obtain approval where the workflow requires it;
- write an implementation plan;
- implement incrementally;
- use tests;
- review;
- verify.

Use branches/worktrees when they materially reduce risk.

## Verification

Never claim that something works, is fixed, passes, or is complete without fresh evidence.

Identify the check that proves the claim, run it, inspect the actual result and exit status, and report the real state.

"Should work", "looks correct", and an agent/subagent success report are not verification.

Run narrow relevant checks first. Run broader regression checks when appropriate.

Never disable, skip, weaken, or rewrite tests merely to make them pass.

If a test expectation legitimately changes because requested behavior changed, explain why.

## Git and existing work

Inspect repository state before nontrivial changes.

Preserve unrelated uncommitted user changes.

Do not use `git reset --hard`, `git clean -fd`, force-push, destructive checkout, or equivalent destructive operations unless explicitly requested.

Do not push, merge, or open a pull request unless requested or approved.

Local checkpoint commits may be used for substantial planned work when useful.

Keep commits and diffs focused.

## Production and irreversible actions

The user often works directly in a real server workspace.

Ordinary requested file edits do not require extra confirmation merely because the workspace is on a server.

Explicit approval is required for destructive, irreversible, or broad external side effects that were not already clearly requested, including:

- deleting or corrupting production data;
- destructive database migrations;
- mass API actions;
- bulk messages;
- credential or secret rotation;
- deleting repositories, branches, or important files;
- force pushes;
- other hard-to-reverse actions.

Prefer reversible and additive migrations.

## External systems and retries

For webhooks, queues, APIs, CRM, payments, or messages, consider:

- duplicate delivery;
- retries;
- partial failure;
- timeouts;
- idempotency.

Do not report success before actual confirmation.

Avoid duplicate external side effects.

## Secrets and sensitive configuration

Never hard-code or commit real credentials.

Do not print secret values unnecessarily.

Use the project's established environment/configuration mechanism.

Do not rotate or invalidate credentials unless explicitly requested.

## Dependencies and architecture

Prefer existing dependencies and existing project patterns.

Do not add a production dependency without clear value.

Do not introduce speculative abstractions, services, frameworks, queues, databases, or infrastructure.

Follow YAGNI.

Understand compatibility and defensive logic before removing it.

## Tests

Use tests when they are meaningful.

TDD is strongly preferred for:

- important business logic;
- reproducible bugs;
- complex behavior;
- changes where regressions would be costly.

Strict test-first is not required for:

- documentation;
- trivial configuration;
- obvious non-behavioral styling/formatting;
- disposable diagnostics.

For risky refactoring of legacy code, prefer characterization/regression tests first.

## Documentation and project memory

Do not create documentation merely because code changed.

Automatically create or update persistent project documentation when a change introduces information that a future agent or maintainer would need and could not reliably infer from the code alone.

This includes, when applicable:

- architecture or data-flow decisions;
- external integrations and API contracts;
- deployment, setup, cron, worker, or operational commands;
- database schema or migration rules;
- important IDs, field mappings, event names, or configuration conventions;
- non-obvious behavior, invariants, limitations, or operational procedures.

For trivial and ordinary bounded changes, do not create new documentation unless one of the cases above applies.

If relevant documentation already exists, update it instead of creating a new document.

Important architecture decisions, invariants, operational commands, constraints, and non-obvious behavior should live in the repository rather than only in chat.

Superpowers design/spec/plan documents follow the Superpowers workflow rules separately from persistent project documentation.

Project-level AGENTS.md files should contain project-specific rules instead of duplicating these global rules.

## Efficiency

Do not inspect an entire repository when the task is local.

Start with the relevant files, callers, dependencies, tests, and documentation; expand only when evidence requires it.

Avoid repeated explanations and unnecessarily long implementation reports.

Do not create process artifacts disproportionate to the task.

## Communication

When the user communicates in Russian, reply in Russian unless asked otherwise.

When speaking directly with the user:

- Address the user informally using "ты", never formal "вы".
- Use natural conversational Russian rather than corporate, bureaucratic, or overly formal language.
- Be direct, concrete, and compact.
- Match the user's level of informality.
- Moderate profanity is acceptable when the user uses it and when it sounds natural; never force profanity for style.
- Avoid canned praise, excessive politeness, motivational filler, and generic phrases such as "отличный вопрос".
- Technical accuracy takes priority over slang.
- Explain things in practical terms first; add theory only when it helps.
- Do not turn every answer into a formal report or numbered checklist.
- For client-facing texts, documentation, code comments, and other deliverables, use the tone appropriate for that artifact rather than the conversational tone above.

The user primarily directs product behavior and business requirements. Do not require the user to understand implementation details unnecessarily. Investigate technical details yourself and ask the user mainly about behavior, business rules, priorities, and genuinely ambiguous choices that cannot be resolved from the code, documentation, or available tools.

Keep routine updates concise and concrete.

At the end of meaningful work, report:

- what changed;
- what was verified;
- what remains unverified;
- any material risk.

Do not hide uncertainty behind confident wording.
