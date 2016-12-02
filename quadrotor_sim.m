% Simulation of Quadrotor Dynamics
% Based on "Modelling and control of quadcopter" (Teppo Luukkonen)
% EENG 436 Final Project
% A. Arkebauer, D. Cody
% October 25, 2016

clear all %#ok<CLALL>
syms time_sym

global T m g M Ax Ay Az C J l k b Ixx Iyy Izz w1 w2 w3 w4 ...
    desired_x desired_y desired_z ...
    desired_x_dot desired_y_dot desired_z_dot ...
    desired_x_ddot desired_y_ddot desired_z_ddot ...
    K_p_z K_d_z K_p_phi K_d_phi K_p_theta K_d_theta K_p_psi K_d_psi ...
    K_i_z K_i_phi K_i_theta K_i_psi ...
    K_p_y K_d_y K_p_x K_d_x ...
    phi_int_err theta_int_err psi_int_err z_int_err ...
    phi_store theta_store psi_store ...
    w1_store w2_store w3_store w4_store t_store


g = 9.81;
M = [k k k k ; 0 -l*k 0 l*k; -l*k 0 l*k 0; b -b b -b]; % mixer matrix

%%%%%%%% Variables which may be changed %%%%%%%%

%% define desired trajectory as symbolic function of time (variable time_sym)

% desired_z_sym(time_sym) = 0.*time_sym;
% desired_z_sym(time_sym) = 5./(1+exp(8-time_sym));
% desired_z_sym(time_sym) = 10 + 0.*time_sym;
% sigma = 1.5;
sigma = 3;
mu = 5;
amp = 10;
desired_x_sym(time_sym) = 0*25*(1/sqrt(2*sigma^2*pi))*exp(-(time_sym-15)^2/(2*sigma^2)); % as of now, must be zero
desired_y_sym(time_sym) = 0+0*time_sym;
desired_z_sym(time_sym) = 0*amp*(1/sqrt(3*sigma^2*pi))*exp(-(time_sym-8)^2/(3*sigma^2));

%% PID Gains
% !!!! Only the Z gains have been tuned !!!!
K_i_z = .0007;
K_p_z = 8.85*0.468;
K_d_z = 3*0.468;

K_i_phi = .75*10^-5;
K_p_phi = 3*10^-4;
K_d_phi = .75*10^-3;

K_i_theta = K_i_phi;
K_p_theta = K_p_phi;
K_d_theta = K_d_phi;

K_i_psi = 3*10^-6;
K_p_psi = 3*10^-3;
K_d_psi = .75*10^-3;

K_p_y = .01;
K_d_y = .007;
K_p_x = K_p_y;
K_d_x = K_d_y;

%% plot settings
linewidth = 1.5;
sim_time = 4; % simulation runtime in seconds
animation_select = 0; % 0: no animation; 1: full motion, one central thrust vector
                      % 2: fixed at origin (only see angular position), one central thrust vector
                      % 3: full motion, four thrust vectors (one for each motor)
                      % 4: fixed at origin (only see angular position), four thrust vectors

%% [!!DEPRECIATED!!] rotor angular velocities (rad/s)
% with original settings from 'Modelling and control of quadcopter' (Teppo Luukkonen):
% wi > 620.61 will cause it to rise
% rotors 2 and 4 spin in - direction, 1 and 3 in + direction
% these are functions of time (not fixed time steps!)

% w1 = @(t) 600*(sin(3*t)+1);
% w2 = @(t) 600*(sin(3*t)+1);
% w3 = @(t) 600*(sin(3*t)+1);
% w4 = @(t) 600*(sin(3*t)+1);

% c = 700;
% w1 = @(t) (c+300)*heaviside(t-.5);
% w2 = @(t) c*heaviside(t-.5);
% w3 = @(t) (c+300)*heaviside(t-.5);
% w4 = @(t) c*heaviside(t-.5);

%% Various constants
k = 2.980*10^-6; % lift constant
m = 0.468; % mass (kg)
l = 0.225; % distance between rotor and center of mass of quad (m)
b = 1.140*10^-7; % drag constant

%% Inertia matrix (kg * m^2)
Ixx = 4.856*10^-3;
Iyy = 4.856*10^-3;
Izz = 8.801*10^-3;

%% Drag force coefficients for velocities (kg/s)
% Ax = 0.25;
% Ay = 0.25;
% Az = 0.25;
Ax = 0;
Ay = 0;
Az = 0;

%% Initial conditions
x0 = 0;
x_dot0 = 0;

y0 = 0;
y_dot0 = 0;

z0 = 0;
z_dot0 = 0;

%% the following are initial angles in radians
phi0 = 0;
phi_dot0 = 0;

theta0 = 0;
theta_dot0 = 0;

psi0 = 0;
psi_dot0 = 0;

%% create anonymous functions for desired position, velocity, acceleration profiles
desired_x = matlabFunction(desired_x_sym);
desired_y = matlabFunction(desired_y_sym);
desired_z = matlabFunction(desired_z_sym);

desired_x_dot_sym = diff(desired_x_sym,time_sym);
desired_y_dot_sym = diff(desired_y_sym,time_sym);
desired_z_dot_sym = diff(desired_z_sym,time_sym);

desired_x_dot = matlabFunction(desired_x_dot_sym);
desired_y_dot = matlabFunction(desired_y_dot_sym);
desired_z_dot = matlabFunction(desired_z_dot_sym);

desired_x_ddot_sym = diff(desired_x_dot_sym,time_sym);
desired_y_ddot_sym = diff(desired_y_dot_sym,time_sym);
desired_z_ddot_sym = diff(desired_z_dot_sym,time_sym);

desired_x_ddot = matlabFunction(desired_x_ddot_sym);
desired_y_ddot = matlabFunction(desired_y_ddot_sym);
desired_z_ddot = matlabFunction(desired_z_ddot_sym);

%% initialize matrices used to store values of motor angular velocities
t_store = [];
w1_store = [];
w2_store = [];
w3_store = [];
w4_store = [];

%% initialize rotor angular velocities
w1 = 0;
w2 = 0;
w3 = 0;
w4 = 0;

% initial combined forces of rotors create thrust T in direction of z-axis
% T = k*(w1(0)^2 + w2(0)^2 + w3(0)^2 + w4(0)^2);
% just call this 0 at time t=0
T = 0;

y = [x0 x_dot0 ...
     y0 y_dot0 ...
     z0 z_dot0 ...
     phi0 phi_dot0 ...
     theta0 theta_dot0 ...
     psi0 psi_dot0];


%% initialize C and J matrices used to calculate angular accelerations
C = zeros(3);
J = zeros(3);

%% RUN SIMULATION
time = [0, sim_time];
options = odeset('RelTol',1e-7,'AbsTol',1e-7,'Stats','on');
[t,y] = ode45(@quadrotor_ode,time,y,options);

%% LINEAR INTERPOLATION TO FIXED TIME STEP TO REDUCE PLOTTING TIME
time_step = 0.05;
times = 0:time_step:max(t); % times at which to update figure
t_fixed = interp1(t,t,times);

    x = interp1(t,y(:,1),times);
    y_plt = interp1(t,y(:,3),times);
    z = interp1(t,y(:,5),times);
    phi = interp1(t,y(:,7),times);
    theta = interp1(t,y(:,9),times);
    psi = interp1(t,y(:,11),times);

    
[t_store,ia,~] = unique(t_store);
t_store_plt = interp1(t_store,t_store,times);
phi_store = interp1(t_store,phi_store(ia),times);
theta_store = interp1(t_store,theta_store(ia),times);
psi_store = interp1(t_store,psi_store(ia),times);
w1_store = interp1(t_store,w1_store(ia),times);
w2_store = interp1(t_store,w2_store(ia),times);
w3_store = interp1(t_store,w3_store(ia),times);
w4_store = interp1(t_store,w4_store(ia),times);


%% PLOT XYZ data
figure('units','normalized','outerposition',[0 0 1 1])
subplot(311)
plot(t_fixed,x, 'LineWidth', linewidth) % x
hold on
plot(t_fixed,desired_x(t_fixed), 'LineWidth', linewidth) % desired x
legend('x', 'desired x')
grid on
title('X Position vs. Time')
xlabel('time (s)')
ylabel('position (m)')

subplot(312)
plot(t_fixed,y_plt, 'LineWidth', linewidth) % y
hold on
plot(t_fixed,desired_y(t_fixed), 'LineWidth', linewidth) % desired y
legend('y', 'desired y')
grid on
title('Y Position vs. Time')
xlabel('time (s)')
ylabel('position (m)')

subplot(313)
plot(t_fixed,z, 'LineWidth', linewidth) % z
hold on
plot(t_fixed,desired_z(t_fixed), 'LineWidth', linewidth) % desired z
legend('z', 'desired z')
grid on
title('Z Position vs. Time')
xlabel('time (s)')
ylabel('position (m)')

%% PLOT ANGLES
figure('units','normalized','outerposition',[0 0 1 1])
subplot(311)
plot(t_fixed,phi, 'LineWidth', linewidth) % phi
hold on
plot(t_store_plt, phi_store, 'LineWidth', linewidth) % desired phi
legend('roll', 'desired roll')
grid on
title('Angular Position vs. Time')
xlabel('time (s)')
ylabel('angular position (rad)')

subplot(312)
plot(t_fixed,theta, 'LineWidth', linewidth) % theta
hold on
plot(t_store_plt, theta_store, 'LineWidth', linewidth) % desired theta
legend('pitch', 'desired pitch')
grid on
title('Angular Position vs. Time')
xlabel('time (s)')
ylabel('angular position (rad)')

subplot(313)
plot(t_fixed,psi, 'LineWidth', linewidth) % psi
hold on
plot(t_store_plt, psi_store, 'LineWidth', linewidth) % desired psi
legend('yaw', 'desired yaw')
grid on
title('Angular Position vs. Time')
xlabel('time (s)')
ylabel('angular position (rad)')

%% Plot Motor input
% filter out duplicates (failed attempts of ode solver) in the stored w_i and time arrays
% unique_ind = boolean(sum(t_store == t));
% t_store = t_store(unique_ind);
% w1_store = w1_store(unique_ind);
% w2_store = w2_store(unique_ind);
% w3_store = w3_store(unique_ind);
% w4_store = w4_store(unique_ind);

figure('units','normalized','outerposition',[0 0 1 1])
subplot(111)
plot(t_store_plt, w1_store, 'LineWidth', linewidth)
hold on
plot(t_store_plt, w2_store, 'LineWidth', linewidth)
hold on
plot(t_store_plt, w3_store, 'LineWidth', linewidth)
hold on
plot(t_store_plt, w4_store, 'LineWidth', linewidth)
legend('\omega_1','\omega_2','\omega_3','\omega_4')
grid on
title('Motor Angular Velocities vs. Time')
xlabel('time (s)')
ylabel('angular velocity (rad/sec)')

%% Animation stuff
% if animation_select == 1
%     % animate quad motion - view_quad has one thrust vector attached to center
%     % of mass
%     view_quad(y(:,1),y(:,4),y(:,7),y(:,10),y(:,13),y(:,16),t)
% else
%     if animation_select == 2
%         
%         % only view rotation of copter (hold position fixed at origin)
%         view_quad(zeros(size(y(:,1))),zeros(size(y(:,4))),zeros(size(y(:,7))),y(:,10),y(:,13),y(:,16),t)
%         
%         %--------------------------------------------------------------------------
%     else
%         if animation_select == 3
%             % animate quad motion - view_quad has four thrust vectors, attached to each
%             % of four motors
%             view_quad2(y(:,1),y(:,4),y(:,7),y(:,10),y(:,13),y(:,16),t)
%             
%         else
%             if animation_select == 4
%                 % only view rotation of copter (hold position fixed at origin)
%                 view_quad2(zeros(size(y(:,1))),zeros(size(y(:,4))),zeros(size(y(:,7))),y(:,10),y(:,13),y(:,16),t)
%             end
%         end
%     end
% end