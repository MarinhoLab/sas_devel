#!/bin/bash
set -e

rosv="jazzy"

####################################################################
#                        Make src directory
####################################################################

mkdir -p $HOME/sas_devel/src
cd $HOME/sas_devel/src

####################################################################
#                        Array of packages
####################################################################

# Packages in https://github.com/SmartArmStack/
sas_pkg_array=(
"sas_core"
"sas_msgs"
"sas_common"
"sas_conversions"
"sas_datalogger"
"sas_robot_driver"
"sas_robot_kinematics"
"sas_robot_driver_denso"
)

# Packages in https://github.com/MarinhoLab/
marinholab_pkg_array=(
"sas_robot_driver_kuka"
"sas_robot_driver_ur"
"sas_robot_driver_coppeliasim"
"sas_operator_side_receiver"
"sas_patient_side_manager"
)

####################################################################
#                        Clone all packages
####################################################################

echo "Cloning or pulling repos at SmartArmStack"
for pkg_name in "${sas_pkg_array[@]}"; do
    if [ ! -d "${pkg_name}" ]; then
        echo "Cloning ${pkg_name}"
        git clone -b "$rosv" git@github.com:SmartArmStack/"$pkg_name".git --recurse-submodules
    else
        echo "Pulling ${pkg_name}"
        cd "${pkg_name}"
        git checkout "$rosv"
        git pull
        cd ..
    fi
done

echo "Cloning or pulling repos at MarinhoLab"
for pkg_name in "${marinholab_pkg_array[@]}"; do
    if [ ! -d "${pkg_name}" ]; then
        echo "Cloning ${pkg_name}"
        git clone -b "$rosv" git@github.com:MarinhoLab/"$pkg_name".git --recurse-submodules
    else
        echo "Pulling ${pkg_name}"
        cd "${pkg_name}"
        git checkout "$rosv"
        git pull
        cd ..
    fi
done

####################################################################
#                        Build and add to source
####################################################################

cd ..
colcon build

echo "source $HOME/sas_devel/install/setup.bash"\
>> /etc/bash_env


