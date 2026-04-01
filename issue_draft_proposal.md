Update the ["Avoid using `var` and `dynamic`"](https://github.com/flutter/flutter/blob/main/docs/contributing/Style-guide-for-Flutter-repo.md#avoid-using-var-and-dynamic) section of the style guide to reflect the current lint configuration.

### Before (current, lines 799-808)

```markdown
All variables and arguments are typed; avoid `dynamic` or `Object` in
any case where you could figure out the actual type. Always specialize
generic types where possible. Explicitly type all list and map
literals. Give types to all parameters, even in closures and even if you
don't use the parameter.

This achieves two purposes: it verifies that the type that the compiler
would infer matches the type you expect, and it makes the code self-documenting
in the case where the type is not obvious (e.g. when calling anything other
than a constructor).
```

### After (suggested)

```markdown
Avoid `dynamic` or `Object` in any case where you could figure out the
actual type. Always specialize generic types where possible. Explicitly
type all list and map literals. Give types to all parameters, even in
closures and even if you don't use the parameter.

For local variables, follow the `omit_obvious_local_variable_types` and
`specify_nonobvious_local_variable_types` lints — omit the type annotation
when the type is obvious from context (e.g. constructor calls), and
specify it when it is not.

This makes the code self-documenting in the case where the type is not
obvious (e.g. when calling anything other than a constructor).
```

Alternatively, if the team prefers different wording, even a one-line note acknowledging the `omit_obvious` lints would clear up the confusion.
