Each `operator<<` overload should have a fallback return **after** the switch body (not inside a `default` case). This ensures:

1. No undefined behavior if an enum is extended without updating the switch.
2. No compiler warnings with `-Wreturn-type` / `-Werror`.
3. **Preserves `-Wswitch` warnings** — the compiler will still warn if a new enum value is added but not handled in the switch. A `default` case would suppress this warning, defeating the purpose of exhaustive enum switching.
4. Compliance with [Abseil Tip #147](https://abseil.io/tips/147): *"if the enclosing function has a return value, we must ensure that the function still either returns a value or crashes in a well-defined and debuggable way."*

The fix for each function is to add a return **after** the switch closing brace:

```cpp
std::ostream& operator<<(std::ostream& os, const DlStrokeCap& cap) {
  switch (cap) {
    case DlStrokeCap::kButt:   return os << "Cap::kButt";
    case DlStrokeCap::kRound:  return os << "Cap::kRound";
    case DlStrokeCap::kSquare: return os << "Cap::kSquare";
  }
  return os << "Cap::???";  // after the switch, NOT as a default case
}
```

**Why not `default:`?** Adding a `default` case to a switch on an enum disables the compiler's `-Wswitch` exhaustiveness check. If someone later adds `DlStrokeCap::kDiamond`, a `default` case would silently handle it, while the "return after switch" pattern produces a compiler warning about the unhandled case. This is the preferred pattern per the Flutter engine style and [Abseil Tip #147](https://abseil.io/tips/147).

**Note**: The same file has 2 existing functions (`DisplayListOpCategory` line 110, `DlFilterMode` line 244) that use `default:` — these are also inconsistent with this guidance and could be updated to match.
