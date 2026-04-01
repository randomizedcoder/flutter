Hi Kate / @Piinks — first off, thank you for the recent work updating the style guide in #181985 and the lint modernization in #179089. These are great improvements for the Flutter community. I wanted to flag a minor point of clarification that might help reduce confusion for contributors.

While contributing to the repo, I noticed that the ["Avoid using `var` and `dynamic`"](https://github.com/flutter/flutter/blob/main/docs/contributing/Style-guide-for-Flutter-repo.md#avoid-using-var-and-dynamic) section of the style guide (lines 799-808) appears to have not been updated alongside those lint changes, and now gives guidance that conflicts with the linter. (Apologies if there is already work in progress on this — I searched existing issues and open PRs but couldn't find it tracked anywhere.)

The style guide currently states ([lines 799-803](https://github.com/flutter/flutter/blob/main/docs/contributing/Style-guide-for-Flutter-repo.md#L799-L803)):

```
All variables and arguments are typed; avoid dynamic or Object in
any case where you could figure out the actual type. Always specialize
generic types where possible. Explicitly type all list and map
literals. Give types to all parameters, even in closures and even if you
don't use the parameter.
```

However, the repo's [`analysis_options.yaml`](https://github.com/flutter/flutter/blob/main/analysis_options.yaml) now has:

- `always_specify_types` **disabled** ([line 43](https://github.com/flutter/flutter/blob/main/analysis_options.yaml#L43))
- `omit_obvious_local_variable_types` **enabled** ([line 148](https://github.com/flutter/flutter/blob/main/analysis_options.yaml#L148))
- `specify_nonobvious_local_variable_types` **enabled** ([line 207](https://github.com/flutter/flutter/blob/main/analysis_options.yaml#L207))

This creates a situation where:

1. The style guide says "All variables ... are typed" and "Give types to all parameters, even in closures"
2. The linter enforces `omit_obvious_local_variable_types`, which requires **omitting** type annotations when the type is obvious from context

As a contributor, it's unclear which guidance takes precedence — particularly for closure parameters, where the style guide text and the lint rules may overlap.

### Existing issue search

I searched existing issues and PRs before filing. Searches included: `omit_obvious_local_variable_types`, `omit_obvious_local_variable_types style guide`, `closure parameter types`, `always_specify_types`, `specify_nonobvious_local_variable_types`, `type annotation closure`, `omit_local_variable_types`, `style guide types closures`, and `closure types lint`. None returned results for this specific discrepancy.

The closest related discussion is in #170435, which covered readability tradeoffs for the new lint rules generally but did not address this style guide section or closure parameters specifically.

### Related issues and PRs

- #180607 — Design doc: Flutter style updates (closed)
- #181985 — Style guide update PR implementing the design doc (merged, did not update this section)
- #179089 — "Modernize framework lints" (merged, introduced the lint changes)
- #178827 — "Unify lints in flutter/flutter and flutter/packages" (tracking issue)
- #170435 — Preview PR with discussion on type annotation readability tradeoffs

Thanks for your valuable time — I hope this helps!
