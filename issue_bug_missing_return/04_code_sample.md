<details open><summary>Code sample</summary>

This is a C++ engine test utility bug. The affected code is in `engine/src/flutter/testing/display_list_testing.cc`.

**Example — one of the 9 affected functions** (line 204):
```cpp
std::ostream& operator<<(std::ostream& os, const DlStrokeCap& cap) {
  switch (cap) {
    case DlStrokeCap::kButt:   return os << "Cap::kButt";
    case DlStrokeCap::kRound:  return os << "Cap::kRound";
    case DlStrokeCap::kSquare: return os << "Cap::kSquare";
  }
  // BUG: no return here — UB if cap is not one of the above
}
```

**Fix** — add a return **after** the switch (not as a `default` case):
```cpp
std::ostream& operator<<(std::ostream& os, const DlStrokeCap& cap) {
  switch (cap) {
    case DlStrokeCap::kButt:   return os << "Cap::kButt";
    case DlStrokeCap::kRound:  return os << "Cap::kRound";
    case DlStrokeCap::kSquare: return os << "Cap::kSquare";
  }
  return os << "Cap::???";  // after the switch — preserves -Wswitch warnings
}
```

**Why not `default:`?** Per [Abseil Tip #147](https://abseil.io/tips/147) and the Flutter engine style, `default` should be avoided in switches on enums because it suppresses `-Wswitch` compiler warnings. If `DlStrokeCap` gains a new value, the "return after switch" approach will produce a compiler warning about the unhandled case, while `default:` would silently swallow it.

**Note**: The same file has 2 existing functions (`DisplayListOpCategory` line 110, `DlFilterMode` line 244) that use `default:` — these are also inconsistent with this preferred pattern.

All 9 affected functions follow the identical pattern — switch on enum, return in each case, no fallthrough return after the switch.

</details>
