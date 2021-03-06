function waypoint_controller_and_simulation()

    % Clear workspace
    clear all;
    close all;
    clc;
    
    % Simulation setup
    [time_params,lumped_params,geometry_params,pid_gains,control_tolerances,control_maximums,x,u,up,ui,ud,MC,error,int,behavior,m_pub,m_msg] = sim_setup();
    
    % Set goal variables
    goal_vars = goal_vars();
              
    % Controller
    for k = 1:1:time_params(3)
        
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
                
    end
    
    % Plot results
    plot_results(time_params,goal_vars,control_tolerances,x,u,up,ui,ud,error);
        
    % Assign relevant stuff to workspace
    assignin('base','x',x)
    assignin('base','error',error)
    assignin('base','u',u)
    assignin('base','behavior',behavior)
    
end

function [time_params,lumped_params,geometry_params,pid_gains,control_tolerances,control_maximums,x,u,up,ui,ud,MC,error,int,behavior,m_pub,m_msg] = sim_setup()

    % Time variables
    dt = .01;                       % simulation time step [s]
    tend = 500;                      % simulation end time [s]
    N = round(tend/dt);             % number of steps [ ]
    time_params = [dt,tend,N];      % output matrix
    
    % Model initial conditions
    x0(1) = 0;          % x-position [m]
    x0(2) = 0;          % y-position [m]
    x0(3) = 3*pi/2;         % psi (heading) [rad]
    x0(4) = 1;          % surge (forward) velocity [m/s]
    x0(5) = 0;          % sway (transverse) velocity [m/s]
    x0(6) = 0;          % yaw (heading) velocity [rad/s]
    
    % Model lumped parameters
    m = 225;                            % mass [kg]
    I = 100;                            % inertia [kg*m^2]
    bu = 25;                            % surge (longitudinal) drag [N*s/m]
    bv = 400;                           % sway (transverse) drag [N*s/m]
    bpsi = 400;                         % yaw (heading) drag [N*s/(m*rad)]
    lumped_params = [m,I,bu,bv,bpsi];   % output matrix
    
    % Model geometry
    theta = deg2rad(30);            % thruster mount angle [rad]
    w = 1.5;                        % width between thrusters [m]
    l = 3;                          % length between thrusters [m]
    geometry_params = [theta,w,l];  % output matrix
    
    % Controller gains
    kp_psi = 10;
    ki_psi = 0;
    kd_psi = 0;
    kp_vel = 20;
    ki_vel = 0;
    kd_vel = 10;
    pid_gains = [kp_psi,ki_psi,kd_psi,kp_vel,ki_vel,kd_vel];
    
    % Control tolerances
    GRT = 0.5;                                          % goal radius tolerance [m]
    PHT = deg2rad(15);                                  % path heading tolerance [rad]
    GHT = deg2rad(5);                                   % goal heading tolerance [rad]
    VT = 0.1;                                           % velocity tolerance [m/s]
    control_tolerances = [GRT,PHT,GHT,VT];              % output matrix
    
    % Control maximums
    u_max = 5;                                          % max surge velocity (control)
    v_max = 5;                                          % max sway velocity (control)
    T1_max = lb2N(55);                                  % max thrust (phyiscal)
    T2_max = lb2N(55);                                  % max thrust (physical)
    T3_max = lb2N(60);                                  % max thrust (physical)
    T4_max = lb2N(60);                                  % max thrust (phyiscal)
    reverse_thrust_ratio = 0.6;                         % max reverse thrust ratio
    control_maximums = [u_max,v_max,T1_max,T2_max,...   % output matrix
        T3_max,T4_max,reverse_thrust_ratio]; 
    
    % Initialize state vector
    x = zeros(6,N);
    
    % Insert initial conditions into state vector
    x(1,1) = x0(1);     % x-position
    x(2,1) = x0(2);     % y-position
    x(3,1) = x0(3);     % psi (heading)
    x(4,1) = x0(4);     % surge (forward) velocity
    x(5,1) = x0(5);     % sway (transverse) velocity
    x(6,1) = x0(6);     % psi (heading)
    
    % Create tracking matrices
    up = zeros(4,N);            % thurster proportional gain [N]
    ui = zeros(4,N);            % thurster integral gain [N]
    ud = zeros(4,N);            % thurster derivative gain [N]
    u = zeros(4,N);             % thurster total gain [N]
    MC = zeros(4,N);            % motor command matrix [%]
    error = zeros(9,N);         % control variable error
    int = zeros(9,N);           % control variable integrator
    behavior = zeros(1,N);      % behavior tracking matrix
    
    % Set up motor publisher
    mQ1_pub = rospublisher('/motor_q1');        % create Matlab publisher to Q1 motor
    mQ2_pub = rospublisher('/motor_q2');        % create Matlab publisher to Q2 motor
    mQ3_pub = rospublisher('/motor_q3');        % create Matlab publisher to Q3 motor
    mQ4_pub = rospublisher('/motor_q4');        % create Matlab publisher to Q4 motor
    m_pub = [mQ1_pub,mQ2_pub,mQ3_pub,mQ4_pub];  % output matrix
    
    % Create servo message
    mQ1_msg = rosmessage(mQ1_pub);              % create blank ros message for /motor_q1
    mQ2_msg = rosmessage(mQ2_pub);              % create blank ros message for /motor_q2
    mQ3_msg = rosmessage(mQ3_pub);              % create blank ros message for /motor_q3
    mQ4_msg = rosmessage(mQ4_pub);              % create blank ros message for /motor_q4
    m_msg = [mQ1_msg,mQ2_msg,mQ3_msg,mQ4_msg];  % output matrix
       
end

function goal_vars = goal_vars()
   
    x_goal = 10;                                            % goal position [m]
    y_goal = 10;                                            % goal position [m]
    psi_goal = deg2rad(270);                                % goal heading [rad]
    goal_vars = [x_goal,y_goal,psi_goal];                   % output matrix

end

function error = update_error(k,x,goal_vars,control_maximums,error)

    % Update errors
    error(1,k) = goal_vars(1)-x(1,k);               % x position goal error
    error(2,k) = goal_vars(2)-x(2,k);               % y position goal error
    error(3,k) = goal_vars(3)-x(3,k);               % psi heading goal error
    error(4,k) = sqrt((goal_vars(1)-x(1,k))^2+...   % path distance error
        (goal_vars(2)-x(2,k))^2);
    error(5,k) = atan2(goal_vars(2)-x(2,k),...      % path heading error
        goal_vars(1)-x(1,k))-x(3,k);
    error(6,k) = control_maximums(1)-x(4,k);        % surge velocity max speed error
    error(7,k) = control_maximums(2)-x(5,k);        % sway velocity max speed error
    error(8,k) = 0-x(4,k);                          % surge velocity stop error
    error(9,k) = 0-x(5,k);                          % sway velocity stop error
    
end

function behavior = select_behavior(k,x,control_tolerances,error,behavior)
    
    if error(4,k) > control_tolerances(1)                                   % robot is not within goal radius tolerance
        if abs(error(5,k)) > control_tolerances(2)                          % robot is not on within path heading tolerance
            behavior(1,k) = 1;
        else
            behavior(1,k) = 2;
        end
    else                                                                    % robot is within goal radius tolerance
        if abs(x(4,k)) || abs(x(5,k)) > control_tolerances(4)               % drive velocity to zero
            behavior(1,k) = 3;
        else
            behavior(1,k) = 4;
        end
    end

end

function [u,up,ui,ud,error,int] = calculate_gains(k,time_params,pid_gains,u,up,ui,ud,error,int,behavior)

    % Behavior Code
    % 1: control robot heading to path heading within PHT
    % 2: drive straight towards waypoint, control velocity
    % 3: control robot surge and sway velocity to zero within ST
    % 4: control robot heading to goal heading within GHT

    if behavior(1,k) == 1
        % Proportional gain
        up(1,k) = pid_gains(1)*error(5,k);                                  % correct path heading to within achieved heading
        up(2,k) = -pid_gains(1)*error(5,k);
        up(3,k) = -pid_gains(1)*error(5,k);
        up(4,k) = pid_gains(1)*error(5,k);
        % Integral gain
        if k > 1
            int(1,k) = int(1,k-1)+error(1,k)*time_params(1);                % increment x position goal error integrator
            int(2,k) = int(2,k-1)+error(2,k)*time_params(1);                % increment y position goal error integrator
            int(3,k) = int(3,k-1)+error(3,k)*time_params(1);                % increment psi heading goal error integrator
            int(4,k) = int(4,k-1)+error(4,k)*time_params(1);                % increment path distance error integrator
            int(5,k) = int(5,k-1)+error(5,k)*time_params(1);                % increment path heading error integrator
            int(6,k) = int(6,k-1)+error(6,k)*time_params(1);                % increment surge velocity max speed error integrator
            int(7,k) = int(7,k-1)+error(7,k)*time_params(1);                % increment sway velocity max speed error integrator
            int(8,k) = int(8,k-1)+error(8,k)*time_params(1);                % increment surge velocity stop error integrator
            int(9,k) = int(9,k-1)+error(9,k)*time_params(1);                % increment sway velocity stop error integrator
            ui(1,k) = pid_gains(2)*(int(5,k));
            ui(2,k) = -pid_gains(2)*(int(5,k));
            ui(3,k) = -pid_gains(2)*(int(5,k));
            ui(4,k) = pid_gains(2)*(int(5,k));
        end
        % Derivative gain
        if k > 1
            ud(1,k) = pid_gains(3)*((error(5,k)-error(5,k-1))/time_params(1));
            ud(2,k) = -pid_gains(3)*((error(5,k)-error(5,k-1))/time_params(1));
            ud(3,k) = -pid_gains(3)*((error(5,k)-error(5,k-1))/time_params(1));
            ud(4,k) = pid_gains(3)*((error(5,k)-error(5,k-1))/time_params(1));
        end
        limit_mode = 2;
    elseif behavior(1,k) == 2
        % Proportional gain
        up(1,k) = pid_gains(4)*error(6,k)-pid_gains(4)*error(7,k);
        up(2,k) = pid_gains(4)*error(6,k)+pid_gains(4)*error(7,k);
        up(3,k) = pid_gains(4)*error(6,k)-pid_gains(4)*error(7,k);
        up(4,k) = pid_gains(4)*error(6,k)+pid_gains(4)*error(7,k);
        % Integral gain
        if k > 1
            int(1,k) = int(1,k-1)+error(1,k)*time_params(1);                % increment x position goal error integrator
            int(2,k) = int(2,k-1)+error(2,k)*time_params(1);                % increment y position goal error integrator
            int(3,k) = int(3,k-1)+error(3,k)*time_params(1);                % increment psi heading goal error integrator
            int(4,k) = int(4,k-1)+error(4,k)*time_params(1);                % increment path distance error integrator
            int(5,k) = int(5,k-1)+error(5,k)*time_params(1);                % increment path heading error integrator
            int(6,k) = int(6,k-1)+error(6,k)*time_params(1);                % increment surge velocity max speed error integrator
            int(7,k) = int(7,k-1)+error(7,k)*time_params(1);                % increment sway velocity max speed error integrator
            int(8,k) = int(8,k-1)+error(8,k)*time_params(1);                % increment surge velocity stop error integrator
            int(9,k) = int(9,k-1)+error(9,k)*time_params(1);                % increment sway velocity stop error integrator
            ui(1,k) = pid_gains(5)*(int(6,k))-pid_gains(5)*(int(7,k));
            ui(2,k) = pid_gains(5)*(int(6,k))+pid_gains(5)*(int(7,k));
            ui(3,k) = pid_gains(5)*(int(6,k))-pid_gains(5)*(int(7,k));
            ui(4,k) = pid_gains(5)*(int(6,k))+pid_gains(5)*(int(7,k));
        end
        % Derivative gain
        if k > 1
            ud(1,k) = pid_gains(6)*((error(6,k)-error(6,k-1))/time_params(1))-...
                pid_gains(6)*((error(7,k)-error(7,k-1))/time_params(1));
            ud(2,k) = pid_gains(6)*((error(6,k)-error(6,k-1))/time_params(1))+...
                pid_gains(6)*((error(7,k)-error(7,k-1))/time_params(1));
            ud(3,k) = pid_gains(6)*((error(6,k)-error(6,k-1))/time_params(1))-...
                pid_gains(6)*((error(7,k)-error(7,k-1))/time_params(1));
            ud(4,k) = pid_gains(6)*((error(6,k)-error(6,k-1))/time_params(1))+...
                pid_gains(6)*((error(7,k)-error(7,k-1))/time_params(1));
        end
        limit_mode = 1;
    elseif behavior(1,k) == 3
        % Proportional gain
        up(1,k) = -pid_gains(4)*error(8,k)+pid_gains(4)*error(9,k);
        up(2,k) = -pid_gains(4)*error(8,k)-pid_gains(4)*error(9,k);
        up(3,k) = -pid_gains(4)*error(8,k)+pid_gains(4)*error(9,k);
        up(4,k) = -pid_gains(4)*error(8,k)-pid_gains(4)*error(9,k);
        % Integral gain
        if k > 1
            int(1,k) = int(1,k-1)+error(1,k)*time_params(1);                % increment x position goal error integrator
            int(2,k) = int(2,k-1)+error(2,k)*time_params(1);                % increment y position goal error integrator
            int(3,k) = int(3,k-1)+error(3,k)*time_params(1);                % increment psi heading goal error integrator
            int(4,k) = int(4,k-1)+error(4,k)*time_params(1);                % increment path distance error integrator
            int(5,k) = int(5,k-1)+error(5,k)*time_params(1);                % increment path heading error integrator
            int(6,k) = int(6,k-1)+error(6,k)*time_params(1);                % increment surge velocity max speed error integrator
            int(7,k) = int(7,k-1)+error(7,k)*time_params(1);                % increment sway velocity max speed error integrator
            int(8,k) = int(8,k-1)+error(8,k)*time_params(1);                % increment surge velocity stop error integrator
            int(9,k) = int(9,k-1)+error(9,k)*time_params(1);                % increment sway velocity stop error integrator
            ui(1,k) = -pid_gains(5)*(int(8,k))+pid_gains(5)*(int(9,k));
            ui(2,k) = -pid_gains(5)*(int(8,k))-pid_gains(5)*(int(9,k));
            ui(3,k) = -pid_gains(5)*(int(8,k))+pid_gains(5)*(int(9,k));
            ui(4,k) = -pid_gains(5)*(int(8,k))-pid_gains(5)*(int(9,k));
        end
        % Derivative gain
        if k > 1
            ud(1,k) = -pid_gains(6)*((error(8,k)-error(8,k-1))/time_params(1))+...
                pid_gains(6)*((error(9,k)-error(9,k-1))/time_params(1));
            ud(2,k) = -pid_gains(6)*((error(8,k)-error(8,k-1))/time_params(1))-...
                pid_gains(6)*((error(9,k)-error(9,k-1))/time_params(1));
            ud(3,k) = -pid_gains(6)*((error(8,k)-error(8,k-1))/time_params(1))+...
                pid_gains(6)*((error(9,k)-error(9,k-1))/time_params(1));
            ud(4,k) = -pid_gains(6)*((error(8,k)-error(8,k-1))/time_params(1))-...
                pid_gains(6)*((error(9,k)-error(9,k-1))/time_params(1));
        end
        limit_mode = 1;
    elseif behavior == 4
        % Proportional gain
        up(1,k) = pid_gains(1)*error(3,k);                                  % correct path heading to within achieved heading
        up(2,k) = -pid_gains(1)*error(3,k);
        up(3,k) = -pid_gains(1)*error(3,k);
        up(4,k) = pid_gains(1)*error(3,k);
        % Integral gain
        if k > 1
            int(1,k) = int(1,k-1)+error(1,k)*time_params(1);                % increment x position goal error integrator
            int(2,k) = int(2,k-1)+error(2,k)*time_params(1);                % increment y position goal error integrator
            int(3,k) = int(3,k-1)+error(3,k)*time_params(1);                % increment psi heading goal error integrator
            int(4,k) = int(4,k-1)+error(4,k)*time_params(1);                % increment path distance error integrator
            int(5,k) = int(5,k-1)+error(5,k)*time_params(1);                % increment path heading error integrator
            int(6,k) = int(6,k-1)+error(6,k)*time_params(1);                % increment surge velocity max speed error integrator
            int(7,k) = int(7,k-1)+error(7,k)*time_params(1);                % increment sway velocity max speed error integrator
            int(8,k) = int(8,k-1)+error(8,k)*time_params(1);                % increment surge velocity stop error integrator
            int(9,k) = int(9,k-1)+error(9,k)*time_params(1);                % increment sway velocity stop error integrator
            ui(1,k) = pid_gains(2)*(int(3,k));
            ui(2,k) = -pid_gains(2)*(int(3,k));
            ui(3,k) = -pid_gains(2)*(int(3,k));
            ui(4,k) = pid_gains(2)*(int(3,k));
        end
        % Derivative gain
        if k > 1
            ud(1,k) = pid_gains(3)*((error(3,k)-error(3,k-1))/time_params(1));
            ud(2,k) = -pid_gains(3)*((error(3,k)-error(3,k-1))/time_params(1));
            ud(3,k) = -pid_gains(3)*((error(3,k)-error(3,k-1))/time_params(1));
            ud(4,k) = pid_gains(3)*((error(3,k)-error(3,k-1))/time_params(1));
        end
        limit_mode = 2;
    end
    
    % Total gain vector
    u(1,k) = up(1,k)+ui(1,k)+ud(1,k);
    u(2,k) = up(2,k)+ui(2,k)+ud(2,k);
    u(3,k) = up(3,k)+ui(3,k)+ud(3,k);
    u(4,k) = up(4,k)+ui(4,k)+ud(4,k);
    
    % Limit thrust control effort
    u = limit_thrust(u,k,limit_mode);
    
    % Convert thrust to motor controller duty cycle
    u = thrust2dutycycle(u);
        
end

function publish_motor_commands(u,MC,k,m_pub,m_msg)

    % Convert thrust to motor controller duty cycle
    MC(1,k) = u(1,k).*(100/55);
    MC(2,k) = u(2,k).*(100/55);
    MC(3,k) = u(3,k).*(100/60);
    MC(4,k) = u(4,k).*(100/60);
    
    % Publish to ROS
    send(m_pub(1),m_msg(1));
    send(m_pub(2),m_msg(2));
    send(m_pub(3),m_msg(3));
    send(m_pub(4),m_msg(4));
    
end

function u = limit_thrust(u,k,limit_mode)

    % mode 1: limit front thruster to 55lb, rear thrusters to 60lb.
    % mode 2: limit al thrusters to 55 lb.
    
    if limit_mode == 1
        % Limit max input
        if u(1,k) >= lb2N(55)
            u(1,k) = lb2N(55);
        elseif u(1,k) <= lb2N(-55)
            u(1,k) = lb2N(-55);
        end
        if u(2,k) >= lb2N(55)
            u(2,k) = lb2N(55);
        elseif u(2,k) <= lb2N(-55)
            u(2,k) = lb2N(-55);
        end
        if u(3,k) >= lb2N(60)
            u(3,k) = lb2N(60);
        elseif u(3,k) <= lb2N(-60)
            u(3,k) = lb2N(-60);
        end
        if u(4,k) >= lb2N(60)
            u(4,k) = lb2N(60);
        elseif u(4,k) <= lb2N(-60)
            u(4,k) = lb2N(-60);
        end
    else 
        % Limit max input
        if u(1,k) >= lb2N(55)
            u(1,k) = lb2N(55);
        elseif u(1,k) <= lb2N(-55)
            u(1,k) = lb2N(-55);
        end
        if u(2,k) >= lb2N(55)
            u(2,k) = lb2N(55);
        elseif u(2,k) <= lb2N(-55)
            u(2,k) = lb2N(-55);
        end
        if u(3,k) >= lb2N(55)
            u(3,k) = lb2N(55);
        elseif u(3,k) <= lb2N(-55)
            u(3,k) = lb2N(-55);
        end
        if u(4,k) >= lb2N(55)
            u(4,k) = lb2N(55);
        elseif u(4,k) <= lb2N(-55)
            u(4,k) = lb2N(-55);
        end
    end

end

function N = lb2N(lb)

    N = lb*4.4482;    

end

function x = plant(k,time_params,x,u,lumped_params,geometry_params)

    % Define lumped and geometry parameters
    m = lumped_params(1);
    I = lumped_params(2);
    bu = lumped_params(3);
    bv = lumped_params(4);
    bpsi = lumped_params(5);
    theta = geometry_params(1);
    w = geometry_params(2);
    l = geometry_params(3);
    
    % Plant
    A = [0 0 0 cos(x(3,k)) -sin(x(3,k)) 0;...
            0 0 0 sin(x(3,k)) cos(x(3,k)) 0;...
            0 0 0 0 0 1;...
            0 0 0 -bu/m 0 0;...
            0 0 0 0 -bv/m 0;...
            0 0 0 0 0 -bpsi/I];
    B = [0 0 0 0;...
        0 0 0 0;...
        0 0 0 0;...
        cos(theta)/m cos(theta)/m cos(theta)/m cos(theta)/m;...
        -sin(theta)/m sin(theta)/m -sin(theta)/m sin(theta)/m;...
        (w*cos(theta))/(2*I)+(l*sin(theta))/(2*I) -(w*cos(theta))/(2*I)-(l*sin(theta))/(2*I) -(w*cos(theta))/(2*I)-(l*sin(theta))/(2*I) (w*cos(theta))/(2*I)+(l*sin(theta))/(2*I)];
    F = eye(6)+A*time_params(1);                                            % Euler integration step
    G = B*time_params(1);
    if k ~= time_params(3)
        x(:,k+1) = F*x(:,k)+G*[u(1,k);u(2,k);u(3,k);u(4,k)];                % Euler solution
    end

end

function plot_results(time_params,goal_vars,control_tolerances,x,u,up,ui,ud,error)

    % Time matrix for plotting
    tt = 0:time_params(1):(time_params(3)-1)*time_params(1);
    
    figure(); 
    th = 0:pi/50:2*pi;
    xunit = control_tolerances(1) * cos(th) + goal_vars(1);
    yunit = control_tolerances(1) * sin(th) + goal_vars(2);
    plot(x(1,:),x(2,:),'b.-',goal_vars(1),goal_vars(2),'r*',xunit, yunit,'r');
    xlabel('x-position [m]');
    ylabel('y-position [m]');
    title('Robot Position');
    axis equal;
    grid on;
    
    figure(); 
    plot(tt,rad2deg(x(3,:)),'b.-')
    xlabel('time [s]');
    ylabel('heading [deg]');
    title('Robot Heading vs. Time');
    grid on;
    
    figure(); 
    plot(tt,x(4,:),'b.-')
    xlabel('time [s]');
    ylabel('surge velocity [m/s]');
    title('Robot Surge Velocity vs. Time');
    grid on;
    
    figure();
    yyaxis left;                % (must have matlab 2016 to run)
    plot(tt,error(4,:));
    ylabel('distance error [m]');
    yyaxis right;
    plot(tt,rad2deg(error(5,:)));
    xlabel('time [s]');
    ylabel('path error [deg]');
    title('Error vs. Time');
    grid on;
    
    figure();
    subplot(4,1,1);
    plot(tt,u(1,:),'k',tt,up(1,:),'r',tt,ui(1,:),'g',tt,ud(1,:),'b');
    ylabel('T1 [N]');
    title('PID Gains vs. Time');
    grid on;
    subplot(4,1,2);
    plot(tt,u(2,:),'k',tt,up(2,:),'r',tt,ui(2,:),'g',tt,ud(2,:),'b');
    ylabel('T2 [N]');
    grid on;
    subplot(4,1,3);
    plot(tt,u(3,:),'k',tt,up(3,:),'r',tt,ui(3,:),'g',tt,ud(3,:),'b');
    ylabel('T3 [N]');
    grid on;
    subplot(4,1,4);
    plot(tt,u(4,:),'k',tt,up(4,:),'r',tt,ui(4,:),'g',tt,ud(4,:),'b'); 
    xlabel('time [s]');
    ylabel('T4 [N]');
    legend('total','proportional','integral','derivative','Location','east');
    grid on;

end

function [h1, h2] = plot_dir(vX, vY)
    % Adapted from https://www.mathworks.com/matlabcentral/fileexchange/1676-plot-with-direction

    rMag = 0.5;

    % X coordinates of tails of arrows
    vXQ0 = vX(1:end-1);
    % Y coordinates of tails of arrows
    vYQ0 = vY(1:end-1);

    % X coordinates of heads of arrows
    vXQ1 = vX(2:end);
    % Y coordinates of heads of arrows
    vYQ1 = vY(2:end);

    % vector difference between heads & tails
    vPx = (vXQ1 - vXQ0) * rMag;
    vPy = (vYQ1 - vYQ0) * rMag;

    % make plot 
    h1 = plot (vX, vY, '.-');
    hold on;
    
    % add arrows 
    h2 = quiver (vXQ0,vYQ0, vPx, vPy, 0, 'r');
    grid on;
    hold off;
    axis equal;

end
