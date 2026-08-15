# SAS CMake Cheatsheet

Patterns extracted from the SmartArmStack CMakeLists.txt files across all submodules.

---

## Project Setup

```cmake
cmake_minimum_required(VERSION 3.11)
project(<project_name>)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wall -Wextra -Wpedantic)
endif()

find_package(ament_cmake REQUIRED)
```

All SAS submodules use **VERSION 3.11** — required for pybind11 embedding and CMake block scope support.

---

## Shared Library (AmenT-exported)

The standard pattern for a library that downstream packages consume via `find_package()`.

```cmake
add_library(${PROJECT_NAME} SHARED
    src/file1.cpp
    src/file2.cpp
)

ament_target_dependencies(${PROJECT_NAME}
    rclcpp geometry_msgs Eigen3 sas_core
)

target_include_directories(${PROJECT_NAME}
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

ament_export_targets(export_${PROJECT_NAME} HAS_LIBRARY_TARGET)
ament_export_dependencies(rclcpp geometry_msgs Eigen3 sas_core)

target_link_libraries(${PROJECT_NAME}
    -ldqrobotics
    Eigen3::Eigen
)

install(DIRECTORY include/ DESTINATION include)

install(TARGETS ${PROJECT_NAME}
    EXPORT export_${PROJECT_NAME}
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
    INCLUDES DESTINATION include
)
```

**Key points**

- Use `${PROJECT_NAME}` as the library name so consumers can link `${PROJECT_NAME}` directly.
- `PUBLIC` generator expressions on `target_include_directories` let downstream packages pick up headers automatically.
- `ament_export_targets` + `ament_export_dependencies` is what makes the package discoverable to others.
- Link external CMake targets by name (e.g. `Eigen3::Eigen`), external `-l` flags directly (e.g. `-ldqrobotics`).

---

## Static Library (Non-ROS / Pure C++)

Used in `sas_core` for the library portion that must compile without ament.

```cmake
find_package(Eigen3 REQUIRED)

add_library(sas_core_pure STATIC)
target_sources(sas_core_pure PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}/../src/sas_clock.cpp
    ${CMAKE_CURRENT_LIST_DIR}/../src/sas_core.cpp
)

set_target_properties(sas_core_pure PROPERTIES
    POSITION_INDEPENDENT_CODE ON
)

target_include_directories(sas_core_pure PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/../include>
    $<INSTALL_INTERFACE:include>
)

target_link_libraries(sas_core_pure PUBLIC -ldqrobotics Eigen3::Eigen)
```

Wrap in an `include(cmake/cpplib.cmake)` to factor out the logic from the top-level CMakeLists.txt.

---

## C++ Binary (Node / Example)

```cmake
add_executable(my_node
    src/my_node.cpp
)

ament_target_dependencies(my_node
    rclcpp sas_core sas_common
)

target_link_libraries(my_node
    ${PROJECT_NAME}          # link the project's own library
    -ldqrobotics
    Eigen3::Eigen
)

target_include_directories(my_node PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_compile_features(my_node PUBLIC c_std_99 cxx_std_17)

install(TARGETS my_node
    DESTINATION lib/${PROJECT_NAME})
```

### Scoped Binary (set/unset pattern)

When defining multiple binaries without duplicating variable names:

```cmake
set(RCLCPP_LOCAL_BINARY_NAME my_node)

add_executable(${RCLCPP_LOCAL_BINARY_NAME}
    src/${RCLCPP_LOCAL_BINARY_NAME}.cpp
)

ament_target_dependencies(${RCLCPP_LOCAL_BINARY_NAME}
    rclcpp sas_core
)

target_link_libraries(${RCLCPP_LOCAL_BINARY_NAME}
    ${PROJECT_NAME}
)

target_include_directories(${RCLCPP_LOCAL_BINARY_NAME} PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_compile_features(${RCLCPP_LOCAL_BINARY_NAME} PUBLIC c_std_99 cxx_std_17)

install(TARGETS ${RCLCPP_LOCAL_BINARY_NAME}
    DESTINATION lib/${PROJECT_NAME})

unset(RCLCPP_LOCAL_BINARY_NAME)
```

---

## Python Library (ament)

```cmake
ament_python_install_package(${PROJECT_NAME})
```

Installs the Python package directory (`<project_name>/`) — including `__init__.py` — into the ament Python install path.

---

## pybind11 Embedded Module

### 1. Import pybind11

```cmake
set(PYBIND11_FINDPYTHON ON)
add_subdirectory(pybind11)
```

The `pybind11/` directory lives at the repository root alongside CMakeLists.txt.

### 2. Build the module

```cmake
pybind11_add_module(_${PROJECT_NAME} SHARED
    src/my_python_module.cpp
)

target_include_directories(_${PROJECT_NAME}
  PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

target_compile_definitions(_${PROJECT_NAME} PRIVATE IS_SAS_PYTHON_BUILD)
target_link_libraries(_${PROJECT_NAME} PRIVATE ${PROJECT_NAME} -ldqrobotics)

install(TARGETS _${PROJECT_NAME}
  DESTINATION "${PYTHON_INSTALL_DIR}/${PROJECT_NAME}"
)
```

**Key points**

- Module name is prefixed with `_` (e.g. `_sas_core`) — the Python `__init__.py` re-exports from this internal module.
- `IS_SAS_PYTHON_BUILD` is a compile definition used across the codebase to guard Python-only vs C++-only code paths.
- If the module needs its own source files (not just a thin wrapper), list them directly in `pybind11_add_module`:

```cmake
pybind11_add_module(_${PROJECT_NAME} SHARED
    src/my_python_module.cpp
    src/my_class.cpp
)
```

### 3. Alternative: cmake include pattern (sas_core)

Factor out into `cmake/pythonlib.cmake`:

```cmake
find_package(Python3 REQUIRED COMPONENTS Development)

set(PYBIND11_FINDPYTHON ON)
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/../pybind11 ${CMAKE_CURRENT_BINARY_DIR}/pybind11)

pybind11_add_module(_sas_core SHARED
    ${CMAKE_CURRENT_LIST_DIR}/../src/sas_core_py.cpp
    ${CMAKE_CURRENT_LIST_DIR}/../src/sas_robot_driver_py.cpp
)

target_include_directories(_sas_core PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/../include>
    $<INSTALL_INTERFACE:include>
)

target_compile_definitions(_sas_core PRIVATE IS_SAS_PYTHON_BUILD)
target_link_libraries(_sas_core PRIVATE sas_core_pure -ldqrobotics)

if(DEFINED _SAS_PYTHON_INSTALL_DIR)
  set(_SAS_PY_DEST "${_SAS_PYTHON_INSTALL_DIR}")
else()
  set(_SAS_PY_DEST "lib/python3/dist-packages/sas_core")
endif()
install(TARGETS _sas_core DESTINATION "${_SAS_PY_DEST}")
```

---

## ROS2 Message Definitions

```cmake
find_package(rosidl_default_generators REQUIRED)

rosidl_generate_interfaces(${PROJECT_NAME}
    "msg/String.msg"
    "msg/Float64.msg"
    "msg/LogDatum.msg"
    DEPENDENCIES
    std_msgs geometry_msgs
)

ament_export_dependencies(rosidl_default_runtime)
```

---

## Third-Party Subdirectory

Embed a third-party library via `add_subdirectory()` and link the resulting target:

```cmake
add_subdirectory(src/kuka)

target_link_libraries(${PROJECT_NAME} PRIVATE kuka_libs_local_static)
```

---

## Library with Embedded Source Files (UR Client Library)

Include source files from an embedded third-party library in your own library target:

```cmake
add_library(${PROJECT_NAME} SHARED
    src/my_driver.cpp

    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/ur/Universal_Robots_Client_Library/src/log.cpp>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/ur/Universal_Robots_Client_Library/src/ur/ur_driver.cpp>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/ur/Universal_Robots_Client_Library/src/rtde/rtde_client.cpp>
)

target_include_directories(${PROJECT_NAME}
    PRIVATE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/src/ur/Universal_Robots_Client_Library/include>
)
```

---

## Install Blocks

### Launch files

```cmake
install(DIRECTORY
    launch
    DESTINATION share/${PROJECT_NAME}/
)
```

### Python scripts (executable)

```cmake
install(PROGRAMS
    scripts/joint_interface_example.py
    scripts/kinematic_control.py
    DESTINATION lib/${PROJECT_NAME}
)
```

### Scripts directory (with execute permissions)

```cmake
install(DIRECTORY
    scripts/
    FILE_PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
    DESTINATION lib/${PROJECT_NAME}
)
```

### Robot config files (YAML)

```cmake
install(DIRECTORY
    robots
    DESTINATION share/${PROJECT_NAME}/
)
```

### Calibration files

```cmake
install(DIRECTORY
    calibration
    DESTINATION share/${PROJECT_NAME}/
)
```

### Specific resource files

```cmake
install(FILES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ur/Universal_Robots_Client_Library/resources/external_control.urscript
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ur/Universal_Robots_Client_Library/examples/resources/rtde_input_recipe.txt
    DESTINATION share/${PROJECT_NAME}
)
```

### SDF / vendor directories (Gazebo)

```cmake
install(DIRECTORY
    launch sdf vendor
    DESTINATION share/${PROJECT_NAME}/
)
```

### Gazebo plugins

```cmake
add_subdirectory(src/plugins/absolute_pose_publisher)
install(TARGETS AbsolutePosePublisher
    LIBRARY DESTINATION share/${PROJECT_NAME}/plugins)
```

### Environment hooks (GZ_SIM_SYSTEM_PLUGIN_PATH)

```cmake
ament_environment_hooks(
    "${CMAKE_CURRENT_SOURCE_DIR}/env-hooks/sas_robot_driver_gazebo.dsv.in"
)
```

---

## Testing

```cmake
if(BUILD_TESTING)
    find_package(ament_lint_auto REQUIRED)
    set(ament_cmake_copyright_FOUND TRUE)
    set(ament_cmake_cpplint_FOUND TRUE)
    ament_lint_auto_find_test_dependencies()
endif()
```

---

## Conditional ROS2 Build

Build the library independently of ament, then add ROS2 integration conditionally:

```cmake
option(ROS2_BUILD "Enable ROS2/ament build" ON)

# Always build the core library
include(cmake/cpplib.cmake)
include(cmake/pythonlib.cmake)

if(ROS2_BUILD)
    find_package(ament_cmake REQUIRED)

    # Create an INTERFACE alias so downstream ROS packages can link sas_core
    add_library(sas_core INTERFACE)
    target_link_libraries(sas_core INTERFACE sas_core_pure)

    ament_export_targets(export_${PROJECT_NAME} HAS_LIBRARY_TARGET)
    ament_export_dependencies(Eigen3)

    install(DIRECTORY include/ DESTINATION include)
    install(TARGETS sas_core sas_core_pure
        EXPORT export_${PROJECT_NAME}
        ARCHIVE DESTINATION lib
        INCLUDES DESTINATION include
    )

    # Example executables
    foreach(_name IN ITEMS example1 example2 example3)
        add_executable(${_name} src/examples/${_name}.cpp)
        target_link_libraries(${_name} sas_core_pure)
        install(TARGETS ${_name} DESTINATION lib/${PROJECT_NAME})
    endforeach()

    ament_package()
endif()
```

---

## ament_package()

Always the last line of the top-level CMakeLists.txt:

```cmake
ament_package()
```

---

## Quick Reference: Block Patterns

| Pattern | Use | Source |
|---|---|---|
| **Shared Library** | Reusable code exported to other packages | Most packages |
| **Static Library** | Pure C++ lib compiled without ament | `sas_core` |
| **C++ Binary** | Executable node or example | All packages |
| **Scoped Binary (set/unset)** | Multiple binaries, scoping via variable | `sas_common`, `sas_robot_driver_*` |
| **pybind11 Module** | Python binding of C++ code | `sas_core`, `sas_common`, `sas_datalogger`, `sas_force_sensor`, `sas_robot_driver`, `sas_robot_kinematics` |
| **Python Package** | Install `__init__.py` + Python sources | All packages with Python |
| **ROS2 Messages** | Define custom msg/srv/action types | `sas_msgs` |
| **Launch Install** | Deploy launch files to share dir | All packages with launch |
| **Scripts Install** | Deploy Python scripts to lib dir | Most packages |
| **Resource Files** | Deploy UR scripts, recipes, YAML configs | `sas_robot_driver_ur`, `sas_robot_driver_kuka`, `sas_ur_control_template` |
| **Gazebo Plugin** | Build + install Gazebo simulation plugin | `sas_robot_driver_gazebo` |
| **Third-Party Subdirectory** | Embed and build external code | `sas_robot_driver_kuka` |
| **Conditional Build** | ROS2-optional library | `sas_core` |
| **Interface Alias** | Expose static lib as ament-discoverable target | `sas_core` |