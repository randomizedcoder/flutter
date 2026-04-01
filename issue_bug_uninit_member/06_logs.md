<details open><summary>Logs</summary>

Static analysis output that identified the bugs:

```console
$ cppcheck --enable=all --std=c++20 \
    engine/src/flutter/impeller/entity/geometry/round_superellipse_geometry.cc \
    engine/src/flutter/shell/platform/common/flutter_platform_node_delegate.h \
    engine/src/flutter/shell/platform/glfw/flutter_glfw.cc

engine/src/flutter/impeller/entity/geometry/round_superellipse_geometry.cc:62:5: error: Member variable 'UnevenQuadrantsRearranger::lengths_' is not initialized in the constructor. [uninitMemberVar]
engine/src/flutter/shell/platform/common/flutter_platform_node_delegate.h:96:3: error: Member variable 'FlutterPlatformNodeDelegate::ax_node_' is not initialized in the constructor. [uninitMemberVar]
engine/src/flutter/shell/platform/glfw/flutter_glfw.cc:160:3: error: Member variable 'FlutterDesktopMessenger::engine_' is not initialized in the constructor. [uninitMemberVar]
```

Related guidance:
- [Abseil Tip #182: "Initialize Your Ints!"](https://abseil.io/tips/182) — *"C++ makes it too easy to leave variables uninitialized. This is scary, because almost any access to an uninitialized object results in Undefined Behavior."*
- [Abseil Tip #61: Default Member Initializers](https://abseil.io/tips/61) — *"Default member initializers will help reduce bugs from omissions, especially when someone adds a new constructor or a new data member."* Notes that fundamental types like raw pointers *"often slip through the cracks and end up uninitialized."*

Note: The Windows version of `FlutterDesktopMessenger` (in `flutter_desktop_messenger.h`) correctly initializes `engine = nullptr`. The GLFW version does not — this inconsistency confirms the initialization was overlooked.

</details>
