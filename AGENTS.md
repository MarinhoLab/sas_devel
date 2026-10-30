# SmartArmStack (sas_devel) — Repository Guide

## Overview

SmartArmStack (`sas`) is a modular ROS 2 robotics software framework for rapid prototyping, testing, and deployment of robot control algorithms. It uses a client–server architecture to separate application logic from ROS 2 communication.

- **Website**: https://smartarmstack.github.io
- **API Docs**: https://marinholab.github.io/sas_devel/index.html
- **Issues**: https://github.com/MarinhoLab/sas_devel/issues
- **ROS 2 distro**: jazzy

## Repository Structure

```
sas_devel/
├── .gitmodules          # 15 submodules under src/
├── docker/              # Docker Compose + Dockerfile for containerised builds
├── .github/workflows/   # CI: build + docs deployment
├── src/examples/        # C++ example programs
├── scripts/             # Helper scripts (check_using_namespace.sh, lint.sh)
├── tools/               # Vendored lint tools (murilos_ros2_linter.py)
├── src/                 # All ROS 2 packages as submodules
│   ├── sas_core/                # Core C++ library (no ROS 2 dependency option)
│   ├── sas_common/              # Shared ROS 2 utilities
│   ├── sas_msgs/                # Custom ROS 2 message definitions
│   ├── sas_conversions/         # ROS 2 ↔ Eigen3/DQRobotics type conversions
│   ├── sas_datalogger/          # Data logging and recording
│   ├── sas_robot_driver/        # Config-space robot control client–server
│   ├── sas_robot_kinematics/    # Task-space (kinematic) control
│   ├── sas_force_sensor/        # Force/torque sensor client–server
│   ├── sas_force_sensor_bota/   # Bota Systems force sensor integration
│   ├── sas_robot_driver_ur/         # Universal Robots driver
│   ├── sas_robot_driver_kuka/       # KUKA driver
│   ├── sas_robot_driver_coppeliasim/ # CoppeliaSim simulation driver
│   ├── sas_robot_driver_gazebo/      # Gazebo simulation driver
│   ├── sas_robot_driver_brov2/       # BlueROV2 underwater vehicle driver
│   ├── sas_kuka_control_template/    # KUKA control template (clone & modify)
│   └── sas_ur_control_template/      # UR control template (clone & modify)
```

### Submodule Owners

- `SmartArmStack/` org: sas_core, sas_common, sas_msgs, sas_conversions, sas_datalogger, sas_robot_driver, sas_robot_kinematics (branch: jazzy)
- `MarinhoLab/` org: sas_robot_driver_*, sas_force_sensor*, sas_*_control_template (branch: jazzy or main)

### Nested Submodules

Several packages embed their own submodules:
- `pybind11` — embedded in sas_common, sas_core, sas_datalogger, sas_force_sensor, sas_robot_driver, sas_robot_kinematics
- `Universal_Robots_Client_Library` — embedded in sas_robot_driver_ur

## Prerequisites

- **ROS 2 jazzy** ( Ubuntu 24.04)
- **Docker** — for containerised builds (recommended)
- **System packages**: `libeigen3-dev`, `libdqrobotics-dev`
- **CMake ≥ 3.11** (sas_core requires 3.11 for pybind11 embedding)
- **Python 3** with development headers (for pybind11 modules)
- **Git** with submodule support

## Getting Started

### Clone with Submodules

```bash
git clone --recursive https://github.com/MarinhoLab/sas_devel.git
cd sas_devel
```

### Update Submodules

```bash
# Initialise and update all submodules to their tracked commits
git submodule update --init --recursive

# Pull latest from remote tracking branches
git submodule update --remote --recursive
```

## Build

### Docker Compose (Recommended)

```bash
cd docker
docker compose up
```

This builds the workspace inside the `ghcr.io/marinholab/gazebo:jazzy` image.

### Docker Build Only

```bash
cd docker
sudo docker build -t sas_devel .
```

### Local colcon Build

```bash
# Ensure all submodules are initialised
git submodule update --init --recursive

colcon build
source install/setup.bash
```

### Build Individual Packages

```bash
colcon build --packages-select sas_core sas_common sas_msgs
```

### Build Order (Dependency Chain)

The recommended build order (topological):

1. `sas_core` — no ROS 2 dependency (pure C++ option available)
2. `sas_msgs` — message definitions
3. `sas_conversions` — depends on sas_core, sas_msgs
4. `sas_common` — depends on sas_conversions
5. `sas_robot_driver` — depends on sas_common, sas_core, sas_conversions
6. `sas_datalogger` — depends on sas_common, sas_core, sas_msgs
7. `sas_force_sensor` — depends on sas_common, sas_core, sas_conversions
8. `sas_robot_kinematics` — depends on sas_common, sas_core, sas_msgs, sas_conversions
9. `sas_robot_driver_ur` — depends on sas_common, sas_core, sas_robot_driver, sas_force_sensor
10. `sas_robot_driver_kuka` — depends on sas_common, sas_core, sas_robot_driver
11. `sas_robot_driver_gazebo` — depends on sas_common, sas_core, sas_robot_driver
12. `sas_robot_driver_coppeliasim` — depends on sas_common, sas_core, sas_robot_driver
13. `sas_robot_driver_brov2` — depends on sas_common, sas_core, sas_robot_driver (plus mavros_msgs, realtime_tools)
14. `sas_force_sensor_bota` — depends on sas_core (ament_python)
15. `sas_kuka_control_template` — depends on sas_robot_driver_kuka
16. `sas_ur_control_template` — depends on sas_robot_driver, sas_robot_driver_ur

## Testing

### Unit tests (in-process client/server round-trips)

`colcon test` gates run in CI (`.github/workflows/lint.yml` → "Test
workspace") for the packages with maintained in-process suites:
`sas_common`, `sas_robot_driver`, `sas_datalogger`, `sas_force_sensor`,
`sas_force_sensor_bota`. They drive the pybind11 clients and servers
against each other over DDS in one process (pytest via
`ament_cmake_pytest`, plus a gtest suite in `sas_common`); the C++
peers need `rclcpp_init()` in addition to `rclpy.init()`, and getters
that report "uninitialized" must be polled while the counterpart keeps
publishing (volatile QoS drops pre-match messages). The other packages
only carry hardware/bring-up tests and are deliberately not in the CI
test step.

### Lint Tests (ament_lint_auto)

Packages with lint auto-testing:
- `sas_conversions`
- `sas_datalogger`
- `sas_robot_driver_coppeliasim`
- `sas_ur_control_template`

Run with:
```bash
colcon test --packages-select <package_name>
colcon test-result --all
```

### Workspace Lint (clang-tidy / ruff / pyright)

Repository-wide linters driven by `scripts/lint.sh`, configured from the
repository root (`.clang-tidy`, `ruff.toml`, `pyrightconfig.json`):

```bash
scripts/lint.sh py     # ruff (style + bugbear) — needs no build
scripts/lint.sh types  # pyright — full results need a built workspace
scripts/lint.sh cpp    # clang-tidy — needs the colcon compile database
scripts/lint.sh ros2   # tools/murilos_ros2_linter.py: spin template, ROS
                       # naming, package.xml vs imports/entry-points
scripts/lint.sh headers # tools/license_header_check.py: Copyright notice in
                       # every first-party source (vendored trees exempt)
scripts/lint.sh all
```

`cpp` and `types` expect a compile database and the compiled pybind11
bindings, i.e. run them after (in docker: inside the container):

```bash
colcon build --cmake-args -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
source install/setup.bash   # puts built bindings on PYTHONPATH for pyright
```

CI: `.github/workflows/lint.yml` runs a fast ruff job plus a
container job (same image as `docker/`) that builds the workspace once
and runs clang-tidy, pyright and
`tools/murilos_ros2_linter.py` (vendored from mmmarinho/ROS2_Tutorial; keep
its `LOCAL` blocks — vendored-tree skips and pip/rosdep dependency
recognition — in sync with the ruff/pyright policies). All lint steps are
hard gates; the tree is lint-clean (0 findings), so keep new code
lint-clean.

### CI Pipeline

The CI pipeline is hosted externally:
- Workflow: `.github/workflows/sas-build-and-test.yml`
- Reuses: `SmartArmStack/smart_arm_stack_ROS2/.github/workflows/sas-isolated-package-build.yml@jazzy`
- Triggers on: push, pull_request, workflow_dispatch
- Builds each submodule package in isolation

### Documentation Deployment

- GitHub Pages workflow: `.github/workflows/pages.yml`
- Generates Doxygen HTML docs and deploys to https://marinholab.github.io/sas_devel/

## Python Bindings

Packages with pybind11 Python modules (underscore-prefixed internal module):
- `_sas_core`, `_sas_common`, `_sas_datalogger`, `_sas_force_sensor`,
  `_sas_robot_driver`, `_sas_robot_kinematics`

Each exposes a Python `__init__.py` that re-exports from the internal pybind11 module. The `IS_SAS_PYTHON_BUILD` compile definition guards Python-only code paths.

## CMake Patterns

All submodules follow consistent CMake patterns documented in `cheatsheet.md`:
- Shared library with ament export targets
- pybind11 embedded modules via `add_subdirectory(pybind11)`
- Scoped binary pattern (set/unset) for multiple executables
- Conditional ROS 2 build (`option(ROS2_BUILD)`) in sas_core
- Static library (`sas_core_pure`) for non-ROS 2 usage

See `cheatsheet.md` for detailed CMake patterns.

## DevContainer

A VS Code devcontainer is configured at `.devcontainer/devcontainer.json`, using the Docker Compose setup. It integrates with IntelliJ IDEA backend.

## Running Gazebo Headless

The Gazebo bridge can run without a GPU/display. Verified in Docker (ROS jazzy, arm64):

- **Server only** is the headless mode: `gz sim <world>.sdf -s` (the `-s`/`--server` flag). The GUI path (`gz sim <world>.sdf`, no `-s`) needs a display and aborts with a Qt/xcb error; `--headless-rendering` is *not* what runs the server.
- The **C++** `sas_object_server_gazebo_node` and `sas_simulator_server_gazebo_node` connect to the `-s` server and publish their topics (`/frame_x/get/pose`, autostart, ...) with no display at all.
- The **Python** robot bridge (`sas_robot_driver_ros_gazebo.py`) imports `gz.transport13`. That binding is present in `ghcr.io/marinholab/gazebo:jazzy` (installed as `python3-gz-transport13`, in `/usr/lib/python3/dist-packages/gz/`) but **absent** from `ghcr.io/marinholab/sas-full:jazzy`. It is normally added to the Gazebo compose image during the `Dockerfile.Gazebo` `colcon build`.
- Full headless flow that works end-to-end: `gz sim <world>.sdf -s` + `robot_driver_server_launch.py name:=<node>` + `object_server_launch.py` + `simulator_server_launch.py` (config keyed by ROS node name). The robot then exposes `/ur_1/get/joint_states` etc.
- UR meshes come from `ros2 run sas_robot_driver_gazebo setup_vendor.sh ur` (clones `Universal_Robots_ROS2_Description` into `~/.sas/.../vendor`); without it the world fails to load with unresolved `model://Universal_Robots_ROS2_Description/...` URIs.

So no Xvfb is required for the simulation; a display (or Xvfb) is only needed if you want the Gazebo GUI.

## Important Notes

- **sas_core** can be built standalone (non-ROS 2) by setting `ROS2_BUILD=OFF`. Useful for CMake FetchContent in external projects.
- **sas_robot_driver_coppeliasim** only works on amd64 (CoppeliaSim limitation).
- **Template packages** (sas_kuka_control_template, sas_ur_control_template) are meant to be cloned and modified, not used directly.
- **sas_robot_driver_kuka** and **sas_robot_driver_ur** should not be cloned directly — use their respective control template packages.
- The `dqrobotics` library is an external dependency required by most packages.
- All packages use `ament_cmake` build type except `sas_force_sensor_bota` which uses `ament_python`.