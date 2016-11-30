% Simulation of Quadrotor Dynamics
% Based on "Modelling and control of quadcopter" (Teppo Luukkonen)
% EENG 436 Final Project
% A. Arkebauer, D. Cody
% October 25, 2016

clear all %#ok<CLALL>
syms time_sym

global T m g Ax Ay Az C J l k b Ixx Iyy Izz w1 w2 w3 w4 ...
    desired_x desired_y desired_z ...
    desired_x_dot desired_y_dot desired_z_dot ...
    desired_x_ddot desired_y_ddot desired_z_ddot ...
    K_p_z K_d_z K_p_phi K_d_phi K_p_theta K_d_theta K_p_psi K_d_psi ...
    K_i_z K_i_phi K_i_theta K_i_psi ...
    phi_int_err theta_int_err psi_int_err z_int_err ...
    w1_store w2_store w3_store w4_store t_store


g = 9.81;

%%%%%%%% Variables which may be changed %%%%%%%%

% define desired trajectory as symbolic function of time (variable time_sym)
desired_x_sym(time_sym) = 0.*time_sym; % as of now, must be zero
desired_y_sym(time_sym) = 0.*time_sym; % as of now, must be zero
% desired_z_sym(time_sym) = 0.*time_sym;
% desired_z_sym(time_sym) = 5./(1+exp(8-time_sym));
% desired_z_sym(time_sym) = 10 + 0.*time_sym;
% sigma = 1.5;
sigma = 3;
mu = 10;
amp = 100;
desired_z_sym(time_sym) = amp*(1/sqrt(2*sigma^2*pi))*exp(-(time_sym-mu)^2/(2*sigma^2));

K_i_z = .0005;
K_p_z = 8.85*0.468;
K_d_z = 3*0.468;

K_i_phi = .75*10^-5;
K_p_phi = 3*10^-3;
K_d_phi = .75*10^-3;

K_i_theta = 3*10^-5;
K_p_theta = 3*10^-3;
K_d_theta = .75*10^-3;

K_i_psi = 3*10^-5;
K_p_psi = 3*10^-3;
K_d_psi = .75*10^-3;


sim_time = 20; % simulation runtime in seconds
animation_select = 0; % 0: no animation; 1: full motion, one central thrust vector
                      % 2: fixed at origin (only see angular position), one central thrust vector
                      % 3: full motion, four thrust vectors (one for each motor)
                      % 4: fixed at origin (only see angular position), four thrust vectors

%%% rotor angular velocities (rad/s)
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

%%% Various constants
k = 2.980*10^-6; % lift constant
m = 0.468; % mass (kg)
l = 0.225; % distance between rotor and center of mass of quad (m)
b = 1.140*10^-7; % drag constant

%%% Inertia matrix (kg * m^2)
Ixx = 4.856*10^-3;
Iyy = 4.856*10^-3;
Izz = 8.801*10^-3;

%%% Drag force coefficients for velocities (kg/s)
% Ax = 0.25;
% Ay = 0.25;
% Az = 0.25;
Ax = 0;
Ay = 0;
Az = 0;

%%% Initial conditions
x0 = 0;
x_dot0 = 0;

y0 = 0;
y_dot0 = 0;

z0 = 0;
z_dot0 = 0;

% the following are initial angles in radians
phi0 = 0;
phi_dot0 = 0;

theta0 = 0;
theta_dot0 = 0;

psi0 = 0;
psi_dot0 = 0;

%%% plot settings
linewidth = 1.5;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% create anonymous functions for desired position, velocity, acceleration
% profiles
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

phi_int_err = 0;
theta_int_err = 0;
psi_int_err = 0;
z_int_err = 0;

% initialize matrices used to store values of motor angular velocities
t_store = [];
w1_store = [];
w2_store = [];
w3_store = [];
w4_store = [];

% initialize rotor angular velocities
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


% initialize C and J matrices used to calculate angular accelerations
C = zeros(3);
J = zeros(3);

time = [0, sim_time];
options = odeset('RelTol',1e-7,'AbsTol',1e-7,'Stats','on');
[t,y] = ode45(@quadrotor_ode,time,y,options);

%%% Plot
figure('units','normalized','outerposition',[0 0 1 1])

% plot positions
% subplot(511)
% plot(t,y(:,1), 'LineWidth', linewidth) % x
% hold on
% plot(t,desired_x(t), 'LineWidth', linewidth) % desired x
% legend('x', 'desired x')
% grid on
% title('X Position vs. Time')
% xlabel('time (s)')
% ylabel('position (m)')
% 
% subplot(512)
% plot(t,y(:,3), 'LineWidth', linewidth) % y
% hold on
% plot(t,desired_y(t), 'LineWidth', linewidth) % desired y
% legend('y', 'desired y')
% grid on
% title('Y Position vs. Time')
% xlabel('time (s)')
% ylabel('position (m)')

% subplot(513)
subplot(311)
plot(t,y(:,5), 'LineWidth', linewidth) % z
hold on
plot(t,desired_z(t), 'LineWidth', linewidth) % desired z
legend('z', 'desired z')
grid on
title('Z Position vs. Time')
xlabel('time (s)')
ylabel('position (m)')


% subplot(514)
subplot(312)
plot(t,y(:,7), 'LineWidth', linewidth) % phi
hold on
plot(t,y(:,9), 'LineWidth', linewidth) % theta
hold on
plot(t,y(:,11), 'LineWidth', linewidth) % psi
legend('\phi','\theta','\psi')
grid on
title('Angular Position vs. Time')
xlabel('time (s)')
ylabel('angular position (rad)')

% filter out duplicates (failed attempts of ode solver) in the stored w_i and time arrays
unique_ind = boolean(sum(t_store == t));
t_store = t_store(unique_ind);
w1_store = w1_store(unique_ind);
w2_store = w2_store(unique_ind);
w3_store = w3_store(unique_ind);
w4_store = w4_store(unique_ind);

% subplot(515)
subplot(313)
plot(t_store, w1_store, 'LineWidth', linewidth)
hold on
plot(t_store, w2_store, 'LineWidth', linewidth)
hold on
plot(t_store, w3_store, 'LineWidth', linewidth)
hold on
plot(t_store, w4_store, 'LineWidth', linewidth)
legend('\omega_1','\omega_2','\omega_3','\omega_4')
grid on
title('Motor Angular Velocities vs. Time')
xlabel('time (s)')
ylabel('angular velocity (rad/sec)')


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
