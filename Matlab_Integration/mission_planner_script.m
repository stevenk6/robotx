% Mission Planner

% Subscriptions
    % Mission Planner
        OGridSub = rossubscriber('/map', 'nav_msgs/OccupancyGrid');     %Occupancy Grid from ROS
        PoseSub = rossubscriber('/poseupdate', 'geometry_msgs/PoseWithCovarianceStamped');  %Orientation of WAM-V from LiDAR 
        CameraHeadSub = rossubscriber('/cameraHead', 'geometry_msgs/Pose');     %Orientation of WAM-V from camera
        CameraColorSub = rossubscriber('/cameraColor', 'std_msgs/UInt8');       %Color from camera
        
    % Path Planner
        GPSSub = rossubscriber('/GPSLocation', 'sensor_msgs/NavSatFix');
        
% Publications
    % Arduino
        mQ1_pub = rospublisher('/motor_q1', 'std_msgs/UInt8');   % create Matlab publisher to Q1 Arduino
        mQ2_pub = rospublisher('/motor_q2', 'std_msgs/UInt8');   % create Matlab publisher to Q2 Arduino
        mQ3_pub = rospublisher('/motor_q3', 'std_msgs/UInt8');   % create Matlab publisher to Q3 Arduino
        mQ4_pub = rospublisher('/motor_q4', 'std_msgs/UInt8');   % create Matlab publisher to Q4 Arduino


% Messages
    % Mission Planner
    
    % Arduino
        mQ1_msg = rosmessage(mQ1_pub);    % create blank ros message for /servoQ1
        mQ2_msg = rosmessage(mQ2_pub);    % create blank ros message for /servoQ2
        mQ3_msg = rosmessage(mQ3_pub);    % create blank ros message for /servoQ3
        mQ4_msg = rosmessage(mQ4_pub);    % create blank ros message for /servoQ4
    
        % Output array
        m_pub = [mQ1_pub,mQ2_pub,mQ3_pub,mQ4_pub];
        m_msg = [mQ1_msg,mQ2_msg,mQ3_msg,mQ4_msg];

% Initialize variables
tic;                % Begin timer, used by motion controller
k = 1;
event_map = zeros([1024, 1024]);    % Map used to record events
event_flag = false;                 % Set to true when a new event is detected

while (1)           % Main loop, condition should be changed to ROS is running
    % Receivers
    OGridData = receive(OGridSub);              % receive message from /map topic
    PoseData = receive(PoseSub);                % receive message from /poseupdate topic

%    CameraHeadData = receive(CameraHeadSub);    % receive message from /cameraHead topic
%    CameraColorData = receive(CameraColorSub);  % receive message from
%    /cameraColor topic
disp('Messages Received');
disp(toc);
    % Extract relevant data from ROS messages
    currentX = PoseData.Pose.Pose.Position.X;   % current X position SLAM estimate
    currentY = PoseData.Pose.Pose.Position.Y;   % current Y position SLAM estimate
    rotationZ = PoseData.Pose.Pose.Orientation.Z;   % current heading orientation
    map = convO2M(OGridData, [currentX, currentY]);

%    phi = CameraHeadData;                       % angle of a detected color
    phi = 30;
    
    map = readBinaryOccupancyGrid(OGridData);       % Binar occupancy grid
    
    % Event Handler
%    [xObj, yObj] = event_location(currentX, currentY, rotationZ, phi, map);
%    event_map(xObj, yObj) = CameraColorData;           % Update event map
    event_flag = true;

    % Wapoint Descision Logic - sets goalX and goalY coordinates
    if (event_flag)
        [destX, destY] = mission_plan(event_map, currentX, currentY);
    end
    
    % Shortest Path using D*
    if (length(destX) > 0)
        goal_vars = find_path(currentX, currentY, destX(1), destY(1), map);
    end
    
    % Motion Controller
    [time_params,lumped_params,geometry_params,pid_gains,control_tolerances,control_maximums,x,u,up,ui,ud,MC,error,int,behavior] = sim_setup();
    
        % Calculate error matrix
        error = update_error(k,x,goal_vars,control_maximums,error);
        
        % Determine robot behavior based on robot state
        behavior = select_behavior(k,x,control_tolerances,error,behavior);
        
        % Calculate error and PID gains for behavior
        [u,up,ui,ud,error,int] = calculate_gains(k,time_params,pid_gains,u,up,ui,ud,error,int,behavior);
        
        % Publish motor command
        publish_motor_commands(u,MC,k,m_pub,m_msg);
        
        % Simulate Plant
        x = plant(k,time_params,x,u,lumped_params,geometry_params);
        
        % Update Loop Variables
        k = int32(mod((k+1), 50000));
    
end