# Razor 9DOF IMU
ROS topic: /imu
Message type: sensor_msgs/Imu.msg

ROS Indigo: http://wiki.ros.org/razor_imu_9dof
Arduino: https://www.sparkfun.com/products/10736

## Installation:
1. Upload Arduino firmware to IMU
2. Install ROS package
   `sudo apt-get install ros-indigo-razor-imu-9dof
3. Copy config file
   `roscd razor_imu_9dof/config`
   `cp razor.yaml my_razor.yaml`
4. Run IMU
   `roslaunch razor_imu_9dof razor-pub.launch`
5. 'Calibrate IMU': https://github.com/Razor-AHRS/razor-9dof-ahrs/wiki/Tutorial
6. Check imu topic
    `rostopic echo /imu`


## To Publish and Run Graphic:
CTL+ALT+T (if you don’t have terminal open)
Type in Command Line: roslaunch razor_imu_9dof razor-pub-and-display.launch

## To Publish Data Only:
CTL+ALT+T (if you don’t have terminal open)
Type in Command Line: roslaunch razor_imu_9dof razor-pub.launch

## To View Published Data:
YOU MUST PUBLISH DATA FIRST AND KEEP PUBLISHING IN ORDER TO VIEW PUBLISHED DATA.

## Open another terminal window - right click on the first terminal window and select “Open Terminal”
Type in Command Line:      rostopic list
			        rostopic echo /imu

You should see a bunch of orientation data.


To Change node Files or “my_razor.yaml” Files:

Type in Command Line:  roscd
			    cd share/razor_imu_9dof/
	For nodes:	    cd nodes
			    sudo vi imu_node.py
	For my_razor.yaml: cd config
			        sudo vi my_razor.yaml


ERRORS:

Arduino cannot find ttyUSB0:
CTL+ALT+T (if you don’t have terminal open)
Type in Command Line:    ls -l /dev/ttyUSB0 
	sudo usermod -a -G dialout ros
	sudo chmod a+rw /dev/ttyUSB0
Change USB number in node accordingly (Change node 

You should be able to upload to arduino/IMU now.
