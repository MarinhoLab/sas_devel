# About

The Smart Arm Stack (`sas`) is a modular robotics software framework designed for rapid prototyping, 
testing, and deployment of robot control algorithms.

## Links

- Website: https://smartarmstack.github.io
- API documentation: https://marinholab.github.io/sas_devel/index.html

## Main philosophy

The core philosophy of sas_devel is to separate application logic from ROS 2 communication using a client–server architecture.
Developers interact through clients and servers, which handle all ROS 2 communication internally, 
eliminating the need to manually create publishers, subscribers, or services. This simplifies development and allows the 
same code to run seamlessly across hardware and simulation.

## Base packages

| Package                                   | Summary                                                                            |
|-------------------------------------------|------------------------------------------------------------------------------------|
| sas_core                                  | Core C++ library providing fundamental functionality independent of ROS 2.         |
| sas_common                                | Shared ROS 2 utilities and helper abstractions used across all packages.           |
| sas_msgs                                  | Wrapper package providing simplified or legacy-compatible ROS message definitions. |
| sas_conversions                           | Utilities for converting ROS 2 messages into primitive and DQ Robotics types.      |
| sas_robot_driver                          | Framework for configuration-space robot control via ROS 2 client–server nodes.     |
| sas_robot_kinematics                      | Framework for task-space (kinematic-level) robot monitoring and control.           |
| sas_datalogger                            | Tools for logging and recording system data during experiments or execution.       |
| sas_operator_side_receiver                | Receives operator-side input data and exposes it as ROS 2 interfaces.              |
| sas_patient_side_manager                  | Coordinates teleoperation by linking operator inputs with multiple robots.         |
| sas_robot_kinematics_constrained_multiarm | Provides centralized kinematic control for multiple robots with constraints.       |

## Specialized packages

Vendor packages provide concrete implementations of the sas_robot_driver interface for specific robot manufacturers or simulation environments.

| Package                         | Summary                                                                                 |
|---------------------------------|-----------------------------------------------------------------------------------------|
| sas_robot_driver_ur             | Client–server driver implementation for controlling Universal Robots (UR) manipulators. |
| sas_robot_driver_kuka           | Client–server driver implementation for controlling KUKA robotic manipulators.          |
| sas_robot_driver_coppeliasim    | Client–server driver implementation for CoppeliaSim simulation.                         |
| sas_robot_driver_gazebo         | Client–server driver implementation for Gazebo simulation.                              |

## Base docker images

- `dqrobotics`: https://github.com/dqrobotics/container
- `ros`: https://github.com/marinholab/ros
- `gazebo`: https://github.com/marinholab/gazebo

## Developer links

- `PPA` and `docker`: https://github.com/SmartArmStack/smart_arm_stack_ROS2
- website devel: https://github.com/SmartArmStack/SmartArmStack.github.io