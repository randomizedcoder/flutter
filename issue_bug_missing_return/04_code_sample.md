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
  // BUG: no default/fallthrough return — UB if cap is not one of the above
}
```

**Correct pattern already used in the same file** (line 244):
```cpp
std::ostream& operator<<(std::ostream& os, const DlFilterMode& mode) {
  switch (mode) {
    case DlFilterMode::kNearest: return os << "FilterMode::kNearest";
    case DlFilterMode::kLinear:  return os << "FilterMode::kLinear";

    default: return os << "FilterMode::????";  // ← correct: has default
  }
}
```

**Fix** — add a default case to each of the 9 switches:
```cpp
std::ostream& operator<<(std::ostream& os, const DlStrokeCap& cap) {
  switch (cap) {
    case DlStrokeCap::kButt:   return os << "Cap::kButt";
    case DlStrokeCap::kRound:  return os << "Cap::kRound";
    case DlStrokeCap::kSquare: return os << "Cap::kSquare";
  }
  FML_UNREACHABLE();  // or: default: return os << "Cap::???";
}
```

All 9 functions follow the identical pattern — switch on enum, return in each case, no default/fallthrough.

</details>
