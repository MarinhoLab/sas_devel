# About

The Smart Arm Stack (`sas`) is a modular robotics software framework designed for rapid prototyping, 
testing, and deployment of robot control algorithms.

## Links

See the website below for installation instructions and docker images.

- Website: https://smartarmstack.github.io
- API documentation: https://marinholab.github.io/sas_devel/index.html

## Issues

For bug reports or issues in any of the packages, please use the following GitHub issue tracker:
- https://github.com/MarinhoLab/sas_devel/issues

## Main philosophy

The core philosophy of sas_devel is to separate application logic from ROS 2 communication using a client–server architecture.
Developers interact through clients and servers, which handle all ROS 2 communication internally, 
eliminating the need to manually create publishers, subscribers, or services. This simplifies development and allows the 
same code to run seamlessly across hardware and simulation.

### Client--Server

As a rule, each `sas` functionality is available via a public `cpp` header in the relevant package. The user of each
functionality uses a client or server as applicable. For most client--server pairs, a `pybind11` wrapper allows the
same functionality in `python`.

Below, each package is listed. For more details, see the `README.md` in each package.

## Base packages

| Package                                                    | Summary                                                                            |
|------------------------------------------------------------|------------------------------------------------------------------------------------|
| [sas_core](src/sas_core/README.md)                         | Core C++ library providing fundamental functionality independent of ROS 2.         |
| [sas_common](src/sas_common/README.md)                     | Shared ROS 2 utilities and helper abstractions used across all packages.           |
| [sas_msgs](src/sas_msgs/README.md)                         | Wrapper package providing simplified or legacy-compatible ROS message definitions. |
| [sas_conversions](src/sas_conversions/README.md)           | Utilities for converting ROS 2 messages into primitive and DQ Robotics types.      |
| [sas_robot_driver](src/sas_robot_driver/README.md)         | Framework for configuration-space robot control via ROS 2 client–server nodes.     |
| [sas_robot_kinematics](src/sas_robot_kinematics/README.md) | Framework for task-space (kinematic-level) robot monitoring and control.           |
| [sas_datalogger](src/sas_datalogger/README.md)             | Tools for logging and recording system data during experiments or execution.       |
| sas_operator_side_receiver                                 | Receives operator-side input data and exposes it as ROS 2 interfaces.              |
| sas_patient_side_manager                                   | Coordinates teleoperation by linking operator inputs with multiple robots.         |
| sas_robot_kinematics_constrained_multiarm                  | Provides centralized kinematic control for multiple robots with constraints.       |

## Specialized packages

Vendor packages provide concrete implementations of the sas_robot_driver interface for specific robot manufacturers or simulation environments.

| Package                                                                    | Summary                                                                                 |
|----------------------------------------------------------------------------|-----------------------------------------------------------------------------------------|
| [sas_robot_driver_ur](src/sas_robot_driver_ur/README.md)                   | Client–server driver implementation for controlling Universal Robots (UR) manipulators. |
| [sas_robot_driver_kuka](src/sas_robot_driver_kuka/README.md)               | Client–server driver implementation for controlling KUKA robotic manipulators.          |
| [sas_robot_driver_coppeliasim](src/sas_robot_driver_coppeliasim/README.md) | Client–server driver implementation for CoppeliaSim simulation.                         |
| [sas_robot_driver_gazebo](src/sas_robot_driver_gazebo/README.md)           | Client–server driver implementation for Gazebo simulation.                              |

## Templates

Packages to clone as a template and edit to your needs. They include simulation and hardware examples.
Videos only render on the website or GitHub, not in these doxygen docs.

| Package                                                              | Summary                                                                                 |
|----------------------------------------------------------------------|-----------------------------------------------------------------------------------------|
| [sas_kuka_control_template](src/sas_kuka_control_template/README.md) | Template package for controlling KUKA robots using the sas_robot_driver_kuka interface. |
| [sas_ur_control_template](src/sas_ur_control_template/README.md)     | Template package for controlling UR robots using the sas_robot_driver_ur interface.     |

## Base docker images

- `dqrobotics`: https://github.com/dqrobotics/container
- `ros`: https://github.com/marinholab/ros
- `gazebo`: https://github.com/marinholab/gazebo

## Developer links

- `PPA` and `docker`: https://github.com/SmartArmStack/smart_arm_stack_ROS2
- website devel: https://github.com/SmartArmStack/SmartArmStack.github.io