If an unhandled enum value reaches any of the 9 switch statements, control falls off the end of a non-void function without a return statement. Per the C++ standard ([dcl.fct/6.6.3]), this is **undefined behavior**.

In practice, compilers may:
- Return garbage / uninitialized memory as the `std::ostream&`
- Crash with a segfault
- Appear to "work" in debug builds but fail in optimized builds (the compiler is allowed to assume UB cannot happen and optimize accordingly)

Currently all enum values are covered, so the UB is not triggered at runtime. However:
- Adding a new enum value without updating the switch will silently introduce UB
- The code produces warnings with `-Wreturn-type`, which blocks builds under `-Werror`
- Static analyzers (cppcheck) flag all 9 as `missingReturn` errors
