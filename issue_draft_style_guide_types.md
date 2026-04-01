# Issue type: Feature request

## Use case

While contributing to the Flutter repo, I noticed that the style guide's ["Avoid using `var` and `dynamic`"](https://github.com/flutter/flutter/blob/main/docs/contributing/Style-guide-for-Flutter-repo.md#avoid-using-var-and-dynamic) section (lines 799-808) appears to be out of date with the current lint configuration.

The style guide currently states:

> All variables and arguments are typed; avoid `dynamic` or `Object` in any case where you could figure out the actual type. Always specialize generic types where possible. Explicitly type all list and map literals. **Give types to all parameters, even in closures** and even if you don't use the parameter.

However, the repo's `analysis_options.yaml` now has:

- **Line 43:** `always_specify_types` disabled, with comment: `# conflicts with omit_obvious_local_variable_types`
- **Line 148:** `omit_obvious_local_variable_types` enabled
- **Line 207:** `specify_nonobvious_local_variable_types` enabled

These lint changes were introduced in PR #179089 ("Modernize framework lints") as part of the lint unification tracked in #178827.

The style guide was subsequently updated in PR #181985 (per design doc #180607), which removed the ["Avoid anonymous parameter names"](https://github.com/flutter/flutter/pull/181985/files) section that previously showed typed closure parameters as recommended practice. However, the "Avoid using `var` and `dynamic`" section was not updated, leaving the "All variables and arguments are typed" and "Give types to all parameters, even in closures" text as-is.

This creates a situation where:

1. The style guide says "All variables ... are typed" and "Give types to all parameters, even in closures"
2. The linter enforces `omit_obvious_local_variable_types`, which requires omitting type annotations on local variables when the type is obvious from context
3. Contributors are unsure which guidance to follow, particularly for closure parameters where these two rules may overlap

I searched existing issues and did not find this specific discrepancy reported. The closest related discussion is in PR #170435, which covered readability tradeoffs for the new lint rules generally, but did not address closure parameters or the style guide text specifically.

## Proposal

Update the ["Avoid using `var` and `dynamic`"](https://github.com/flutter/flutter/blob/main/docs/contributing/Style-guide-for-Flutter-repo.md#avoid-using-var-and-dynamic) section of the style guide to reflect the current lint configuration. Specifically, clarify:

1. That local variables should follow `omit_obvious_local_variable_types` / `specify_nonobvious_local_variable_types` (i.e., omit the type when it is obvious from context)
2. Whether the "Give types to all parameters, even in closures" guidance still applies, or whether closure parameters should also follow the "obvious/non-obvious" distinction

This would help contributors understand the expected behavior without having to cross-reference the style guide text against the `analysis_options.yaml` lint rules.

### Related issues and PRs

- #180607 — Design doc: Flutter style updates (closed)
- #181985 — Style guide update PR implementing the design doc (merged, did not update this section)
- #179089 — "Modernize framework lints" (merged, introduced the lint changes)
- #178827 — "Unify lints in flutter/flutter and flutter/packages" (tracking issue)
- #170435 — Preview PR with discussion on type annotation readability tradeoffs
