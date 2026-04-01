Each `operator<<` overload should have a `default` case (or a return/crash after the switch) that handles unexpected enum values. This ensures:

1. No undefined behavior if an enum is extended without updating the switch.
2. No compiler warnings with `-Wreturn-type` / `-Werror`.
3. Compliance with [Abseil Tip #147](https://abseil.io/tips/147): *"if the enclosing function has a return value, we must ensure that the function still either returns a value or crashes in a well-defined and debuggable way."*

**Note**: The same file already has 2 functions that correctly handle this — `operator<<` for `DisplayListOpCategory` (line 110) and `DlFilterMode` (line 244) both include `default: return os << "...???";` cases. The fix is to follow the same pattern across all 9 affected functions:

```cpp
default: return os << "EnumType::???";
```

Or alternatively, add `FML_UNREACHABLE()` after the switch body (per Abseil Tip #147's crash-on-unexpected-value approach).
