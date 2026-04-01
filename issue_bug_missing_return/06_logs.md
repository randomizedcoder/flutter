<details open><summary>Logs</summary>

Static analysis output that identified the bugs:

```console
$ cppcheck --enable=all --std=c++20 engine/src/flutter/testing/display_list_testing.cc
engine/src/flutter/testing/display_list_testing.cc:149:1: error: Found an exit path from function with non-void return type that has missing return statement [missingReturn]
engine/src/flutter/testing/display_list_testing.cc:192:1: error: Found an exit path from function with non-void return type that has missing return statement [missingReturn]
engine/src/flutter/testing/display_list_testing.cc:201:1: error: Found an exit path from function with non-void return type that has missing return statement [missingReturn]
engine/src/flutter/testing/display_list_testing.cc:209:1: error: Found an exit path from function with non-void return type that has missing return statement [missingReturn]
engine/src/flutter/testing/display_list_testing.cc:217:1: error: Found an exit path from function with non-void return type that has missing return statement [missingReturn]
engine/src/flutter/testing/display_list_testing.cc:225:1: error: Found an exit path from function with non-void return type that has missing return statement [missingReturn]
engine/src/flutter/testing/display_list_testing.cc:234:1: error: Found an exit path from function with non-void return type that has missing return statement [missingReturn]
engine/src/flutter/testing/display_list_testing.cc:242:1: error: Found an exit path from function with non-void return type that has missing return statement [missingReturn]
engine/src/flutter/testing/display_list_testing.cc:289:1: error: Found an exit path from function with non-void return type that has missing return statement [missingReturn]
```

Manual review confirmed: all 9 functions are `operator<<` overloads returning `std::ostream&` with switch statements that cover current enum values but lack a `default` case or post-switch return. This is undefined behavior per [dcl.fct/6.6.3] if an unhandled value reaches the switch.

Note: The same file already has 2 functions (`DisplayListOpCategory` at line 110 and `DlFilterMode` at line 244) that correctly include `default` cases — these 9 functions should follow the same pattern.

</details>
