
%%% Fluid simulation


close all;
clear all;
clearvars;
%clearvars -except sensor_data

% Simulation settings

DATA_CAST = 'single';    % The data type used within the time loop can be set using the optional input parameter  DataCast  
MASK_PLANE = 'xy';       % Option for selecting plane
USE_STATISTICS = true;   % Option to run simulation mode

% Define kGrid

PML_X_SIZE = 10;         % Perfectly Matched Layer (PML) PML_size is used to add a layer so that the wave dooes not reflect back from the boundary
PML_Y_SIZE = 10; 
PML_Z_SIZE = 10;


%Grid points

Nx = 512- 2*PML_X_SIZE;    % excluding PML layer, all Nx, Ny, Nz (including PML) are power of 2 % 456
Ny = 196 - 2*PML_Y_SIZE; 
Nz = 196 - 2*PML_Z_SIZE;

% grid step size

%dx=0.027e-3; %unit is meter
dx=0.03e-3;
dy=dx;
dz=dx;

%create k-space
kgrid = kWaveGrid(Nx, dx, Ny, dy, Nz, dz);         % Perfectly Matched Layer (PML) PML_size is used to add a layer so that the wave dooes not reflect back from the boundary

% medium properties allocation

%define top layer_water
cp1 = 1480;     % Longitudinal wave speed
cs1 = 0;        % shear wave speed
rho1 = 1000;    %density
alpha0_p1 = 0.002;        % absorption coefficient for water
alpha0_s1 = 0.002;        % absorption coefficient for water (shear)

%define bottom layer_tissue
cp2 = 1540;   % Longitudinal wave speed
cs2 = 10;     % shear wave speed
rho2 = 1050;  %density
%alpha0_p2 = 0.5;        % absorption coefficient
%alpha0_s2 = 0.5;        % absorption coefficient

alpha0_p2 = 0;        % absorption coefficient
alpha0_s2 = 2/(2*rho2*cs2.^3) ;        % absorption coefficient
alpha0_s2=neper2db(alpha0_s2, 1.5)

% time array for the simulation

cfl = 0.3;
t_end = 20e-6;
kgrid.makeTime(cp1, cfl, t_end);


% define position of heterogeneous slab
slab                = zeros(Nx, Ny, Nz);
slab(200*Nx/492:end, :, :)   = 1;

% define properties of the input signal

source_strength = 1;
tone_burst_freq = 5e6; 
tone_burst_cycles = 1000;%??
input_signal = toneBurst(1/kgrid.dt, tone_burst_freq, tone_burst_cycles);
% input_signal = (source_strength ./ (rho1 .* cp1)) .* input_signal; %scaling source signal
input_signal = ((source_strength)).* input_signal;        %Why?
 
 % transducer elements
 
transducer.number_elements = 17; 
transducer.element_width = 0.27e-3/dx;       %converting mm in to grid points for kWaveTransducer (0.27-0.03=pitch-kerf)
transducer.element_length = 5e-3/dz; 
transducer.element_spacing = 0.03e-3/dx; 
transducer.radius = inf;

transducer_width = transducer.number_elements * transducer.element_width ...
+ (transducer.number_elements - 1) * transducer.element_spacing;

transducer.position = round([1, Ny/2 - transducer_width/2, Nz/2 - transducer.element_length/2]);


% transducer properties

transducer.sound_speed = 1540; % sound speed [m/s]
transducer.focus_distance = 7.5e-3; % focus distance [m]
%transducer.elevation_focus_distance = 18e-3; %not needed for our case
%transducer.elevation_focus_distance = 'inf'; %not needed for our case
transducer.steering_angle = 0; 

% transducer apodization
transducer.transmit_apodization = 'Rectangular';    %The settings for transmit_apodization and receive_apodization control the relative weights assigned to the signal driving each of the active transducer elements.
transducer.receive_apodization = 'Rectangular';

transducer.active_elements = zeros(transducer.number_elements, 1); %option to select the active elements in transducer
transducer.active_elements(1:transducer.number_elements) = 1;
transducer.input_signal = input_signal;

% create the transducer using the defined settings
transducer = kWaveTransducer(kgrid, transducer);
transducer.properties;

% sensor mask
sensor.mask = zeros(Nx, Ny, Nz);
switch MASK_PLANE
    
case 'xy'          % A case option enable to select different planes for 3D case. 
sensor.mask(:, :, round(Nz/2)) = 1;
%sensor.mask(:, :, 98:102) = 1;
Nj = Ny;
j_vec = kgrid.y_vec;
j_label = 'y';


case 'xz'
sensor.mask(:, round(Ny/2), :) = 1;
Nj = Nz;
j_vec = kgrid.z_vec;
j_label = 'z';
end

% value to be stored
if USE_STATISTICS      % If Use_statistics is not used then there will be no secord for sensor. 
sensor.record = {'p','p_rms','u_non_staggered','I','I_avg'};
end

% input argyment for the simulation
input_args = {'DisplayMask', transducer.active_elements_mask, ...
'PMLInside', false, 'PlotPML', false, 'PMLSize', [PML_X_SIZE, PML_Y_SIZE, PML_Z_SIZE], ...
'DataCast', DATA_CAST, 'PlotScale', [-1, 1] * source_strength};


% assign the medium properties

medium.sound_speed            = cp1*ones(Nx, Ny, Nz);
medium.sound_speed(slab == 1) = cp2;
medium.density                = rho1*ones(Nx, Ny, Nz);
medium.density(slab == 1)     = rho2;
medium.alpha_coeff            = alpha0_p1*ones(Nx, Ny, Nz);
medium.alpha_coeff(slab == 1) = alpha0_p2;
medium.alpha_power            = 1.5;

%run acoustic simulation
sensor_data = kspaceFirstOrder3D(kgrid, medium, transducer, sensor, input_args{:});
% save('sensor_data.mat', 'sensor_data','-v7.3');

figure('Position', [100, 100, 1400, 1400]); 

% visualization beamfield
subplot(1, 2, 1);
P=sensor_data.p_rms;
P=reshape(P,[Nx,Ny]);
Prms_db=(P./max(P(:)));
% subplot(1, 3, 1);
 %imagesc(kgrid.y_vec*1e3, kgrid.x_vec*1e3, Prms_db);
imagesc(kgrid.y_vec*1e3, kgrid.x_vec*1e3+1.35, Prms_db);
set(gca, 'FontSize', 15) % Adjust the font size as needed
set(gca, 'FontWeight', 'bold')
xlabel('x [mm]' );
ylabel('z [mm]');
axis image;
h = colorbar;
colormap('jet');
 caxis([0, 1]);
title(' Normalized Pressure (RMS)',FontSize=22);
%ylabel(h, '[dB]');

% Second subplot
subplot(1, 2, 2);
rowToPlot = round(Ny / 2);
p1 = sensor_data.p_rms;
p1 = reshape(p1, [Nx, Ny]);
p1 = p1 ./ max(p1(:));
p1 = p1(:, rowToPlot);

plot(p1, (kgrid.x_vec * 1e3+1.35), 'LineWidth', 2);
set(gca, 'FontSize', 22, 'FontWeight', 'bold', 'YDir', 'reverse', 'YLim', [-6,8.76]);


% Adjust the aspect ratio to make the physical size of the second subplot the same as the first subplot
subplotPos = get(gca, 'Position');
%subplot(1, 2, 2);
scaleFactor=1;
set(gca, 'Position', [subplotPos(1), subplotPos(2), subplotPos(3) * scaleFactor, subplotPos(4)]);

title('Normalized Pressure at x = 0 mm');
xlabel('P', 'FontWeight', 'bold');
ylabel('z [mm]', 'FontWeight', 'bold');

%% QuasiPW forces


%Pressure=sensor_data.p;
%Pressure=reshape(Pressure, [Nx, Ny,kgrid.Nt]);
% save('Pressure.mat', 'Pressure','-v7.3');
load('C:\Users\BARL\Downloads\k-wave-toolbox-version-1.2.1\k-Wave\Scholte_final\Ux');
load('C:\Users\BARL\Downloads\k-wave-toolbox-version-1.2.1\k-Wave\Scholte_final\Uy');
load('C:\Users\BARL\Downloads\k-wave-toolbox-version-1.2.1\k-Wave\Scholte_final\Uz');

Ux1=(sensor_data.ux_non_staggered);
Ux1=reshape(Ux1, [Nx, Ny,kgrid.Nt]);

Uy1=(sensor_data.uy_non_staggered);
Uy1=reshape(Uy1, [Nx, Ny,kgrid.Nt]);

Uz1=(sensor_data.uz_non_staggered);
Uz1=reshape(Uz1, [Nx, Ny,kgrid.Nt]);

% save('Ux.mat', 'Ux1','-v7.3');
% save('Uy.mat', 'Uy1','-v7.3');
% save('Uz.mat', 'Uz1','-v7.3');

%velocity wise multiplication for Eqn 13 (element multiplication)

UxUy=Ux1.*Uy1; 
UxUx=Ux1.*Ux1;
UyUy=Uy1.*Uy1;
UzUy=Uz1.*Uy1;
UzUx=Uz1.*Ux1;

% gradient calculation

Uxx_y1_all = zeros(size(UxUx));
Uxx_x1_all = zeros(size(UxUx));

% Loop through each time step
for tIndex = 1:size(UxUx, 3)
    % Compute the gradient along x and y directions for the current time step
    [Uxx_y1,Uxx_x1] = gradient(UxUx(:, :, tIndex), dy, dx);
    
    % Store the results in the corresponding arrays
%     Uxx_y1_all(:, :, tIndex) = Uxx_y1;
    Uxx_x1_all(:, :, tIndex) = Uxx_x1;
end

Uyy_y1_all = zeros(size(UyUy));
Uyy_x1_all = zeros(size(UyUy));

% Loop through each time step
for tIndex = 1:size(UyUy, 3)
    % Compute the gradient along x and y directions for the current time step
    [Uyy_y1,Uyy_x1] = gradient(UyUy(:, :, tIndex), dx, dy);
    
    % Store the results in the corresponding arrays
    Uyy_y1_all(:, :, tIndex) = Uyy_y1;
%     Uyy_x1_all(:, :, tIndex) = Uyy_x1;
end

Uxy_y1_all = zeros(size(UxUy));
Uxy_x1_all = zeros(size(UxUy));

% Loop through each time step
for tIndex = 1:size(UxUy, 3)
    % Compute the gradient along x and y directions for the current time step
    [Uxy_y1,Uxy_x1] = gradient(UxUy(:, :, tIndex), dy, dx);
    
    % Store the results in the corresponding arrays
    Uxy_y1_all(:, :, tIndex) = Uxy_y1;
    Uxy_x1_all(:, :, tIndex) = Uxy_x1;
end


Uzx_y1_all = zeros(size(UzUx));
Uzx_x1_all = zeros(size(UzUx));

for tIndex = 1:size(UzUx, 3)
    % Compute the gradient along x and y directions for the current time step
    [Uzx_y1,Uzx_x1] = gradient(UzUx(:, :, tIndex), dy, dx);
    
    % Store the results in the corresponding arrays
    Uzx_y1_all(:, :, tIndex) = Uzx_y1;
    Uzx_x1_all(:, :, tIndex) = Uzx_x1;
end


Uzy_y1_all = zeros(size(UzUy));
Uzy_x1_all = zeros(size(UzUy));

for tIndex = 1:size(UzUy, 3)
    % Compute the gradient along x and y directions for the current time step
    [Uzy_y1,Uzy_x1] = gradient(UzUy(:, :, tIndex), dy, dx);
    
    % Store the results in the corresponding arrays
    Uzy_y1_all(:, :, tIndex) = Uzy_y1;
    Uzy_x1_all(:, :, tIndex) = Uzy_x1;
end


Fx1=Uxy_y1_all+Uxx_x1_all;
density=squeeze(medium.density(:,:,round(Nz/2)));
speed=squeeze(medium.sound_speed(:,:,round(Nz/2)));

Fx1=-density.*(Fx1);%DYNAMIC
Fx1=rms(Fx1,  3); %root mean square for average FOR STATIC

Fy1=Uxy_x1_all+Uyy_y1_all;
Fy1=-density.*(Fy1);
Fy1=rms(Fy1, 3);

Fz1=Uzy_y1_all+Uzx_x1_all;
Fz1=-density.*(Fz1);
Fz1=rms(Fz1, 3);


F_max = max([max(Fx1(:)), max(Fy1(:)), max(Fz1(:))]);
Fx1=Fx1./F_max;
Fy1=Fy1./F_max;
Fz1=Fz1./F_max;

fig = figure;
fig.OuterPosition = [100 100 1400 800];

% Define axis limits for all subplots
axis_limits = [min(kgrid.y_vec*1e3), max(kgrid.y_vec*1e3), min(kgrid.x_vec*1e3)+1.35, max(kgrid.x_vec*1e3)+1.35];
sfh1 = subplot(1, 3, 1);
 sfh1.Position = sfh1.Position - [-0.04 0 0.028 0];

imagesc(kgrid.y_vec*1e3, kgrid.x_vec*1e3+1.35, Fx1, [0, 1]);
set(gca, 'FontSize', 18, 'FontWeight', 'bold', 'XLim', axis_limits(1:2), 'YLim', axis_limits(3:4));
xlabel('x [mm]', 'FontWeight', 'bold', 'FontSize', 18);
ylabel('z [mm]', 'FontWeight', 'bold', 'FontSize', 18);
colormap(gca, 'jet');
title('fz', 'FontSize', 18);

sfh2 =subplot(1, 3, 2);
imagesc(kgrid.y_vec*1e3, kgrid.x_vec*1e3+1.35, Fy1, [0, 1]);
set(gca, 'FontSize', 18, 'FontWeight', 'bold', 'XLim', axis_limits(1:2), 'YLim', axis_limits(3:4));
xlabel('x [mm]', 'FontWeight', 'bold', 'FontSize', 18);
ylabel('z [mm]', 'FontWeight', 'bold', 'FontSize', 18);
colormap(gca, 'jet');
h = colorbar;
title('fx', 'FontSize', 18);

% Create a color bar for fz and fx combined
sfh3 =subplot(1, 3, 3);
imagesc(kgrid.y_vec*1e3, kgrid.x_vec*1e3+1.35, Fz1,[0, 1e-5]);
set(gca, 'FontSize', 18, 'FontWeight', 'bold', 'XLim', axis_limits(1:2), 'YLim', axis_limits(3:4));
xlabel('x [mm]', 'FontWeight', 'bold', 'FontSize', 18);
ylabel('z [mm]', 'FontWeight', 'bold', 'FontSize', 18);
colormap(gca, 'jet');
h = colorbar;
% set(h, 'Position', [0.92, 0.1, 0.02, 0.8]);  % Adjust the position as needed
title('fy', 'FontSize', 18);

%% APW
%S=load('C:\Users\BARL\Downloads\k-wave-toolbox-version-1.2.1\k-Wave\Scholte_final\sensor_data');
Ix=(sensor_data.Ix);
Ix=reshape(Ix, [Nx, Ny,kgrid.Nt]);
Ix=squeeze(rms(Ix,3));

Iy=(sensor_data.Iy);
Iy=reshape(Iy, [Nx, Ny,kgrid.Nt]);
Iy=squeeze(rms(Iy,3));

Iz=(sensor_data.Iz);
Iz=reshape(Iz, [Nx, Ny,kgrid.Nt]);
Iz=squeeze(rms(Iz,3));

%attenuation=squeeze(medium.alpha_coeff(:,:,round(Nz/2)));

%0.0022 dB/(MHz^y-cm)=(0.115*0.0022) np/(MHz-cm)=(0.115*0.0022*5^2) np/cm=(0.115*0.0022*5*100) np/m =0.1265 np/m;
alpha1=0.115*0.0022*25*100;  
alpha2=0.115*0.5*(5^1.5)*100; 
attenuation=alpha1*ones(Nx,Ny);
attenuation(200*Nx/492:end, :)=alpha2;



Fx3=(2.*attenuation.*Ix)./(speed);
Fy3=(2.*attenuation.*Iy)./(speed);
Fz3=(2.*attenuation.*Iz)./(speed);

F_max = max([max(Fx3(:)), max(Fy3(:)), max(Fz3(:))]);
Fx3=Fx3./F_max;
Fy3=Fy3./F_max;
Fz3=Fz3./F_max;

fig = figure;
fig.OuterPosition = [100 100 1400 800];

% Define axis limits for all subplots
axis_limits = [min(kgrid.y_vec*1e3), max(kgrid.y_vec*1e3), min(kgrid.x_vec*1e3)+1.35, max(kgrid.x_vec*1e3)+1.35];
sfh1 = subplot(1, 3, 1);
 sfh1.Position = sfh1.Position - [-0.04 0 0.028 0];

imagesc(kgrid.y_vec*1e3, kgrid.x_vec*1e3+1.35, Fx3, [0, 1]);
set(gca, 'FontSize', 18, 'FontWeight', 'bold', 'XLim', axis_limits(1:2), 'YLim', axis_limits(3:4));
xlabel('x [mm]', 'FontWeight', 'bold', 'FontSize', 18);
ylabel('z [mm]', 'FontWeight', 'bold', 'FontSize', 18);
colormap(gca, 'jet');
title('fz', 'FontSize', 18);

sfh2 =subplot(1, 3, 2);
imagesc(kgrid.y_vec*1e3, kgrid.x_vec*1e3+1.35, Fy3, [0, 1]);
set(gca, 'FontSize', 18, 'FontWeight', 'bold', 'XLim', axis_limits(1:2), 'YLim', axis_limits(3:4));
xlabel('x [mm]', 'FontWeight', 'bold', 'FontSize', 18);
ylabel('z [mm]', 'FontWeight', 'bold', 'FontSize', 18);
colormap(gca, 'jet');
h = colorbar;
title('fx', 'FontSize', 18);

% Create a color bar for fz and fx combined
sfh3 =subplot(1, 3, 3);
imagesc(kgrid.y_vec*1e3, kgrid.x_vec*1e3+1.35, Fz3,[0, 1e-5]);
set(gca, 'FontSize', 18, 'FontWeight', 'bold', 'XLim', axis_limits(1:2), 'YLim', axis_limits(3:4));
xlabel('x [mm]', 'FontWeight', 'bold', 'FontSize', 18);
ylabel('z [mm]', 'FontWeight', 'bold', 'FontSize', 18);
colormap(gca, 'jet');
h = colorbar;
% set(h, 'Position', [0.92, 0.1, 0.02, 0.8]);  % Adjust the position as needed
title('fy', 'FontSize', 18);




%%  Second-order approximation

Ux2=load('C:\Users\BARL\Downloads\k-wave-toolbox-version-1.2.1\k-Wave\Scholte_final\Ux');
Ux2=Ux2.Ux1;
Uy2=load('C:\Users\BARL\Downloads\k-wave-toolbox-version-1.2.1\k-Wave\Scholte_final\Uy');
Uy2=Uy2.Uy1;
Uz2=load('C:\Users\BARL\Downloads\k-wave-toolbox-version-1.2.1\k-Wave\Scholte_final\Uz');
Uz2=Uz2.Uz1;
p=load('C:\Users\BARL\Downloads\k-wave-toolbox-version-1.2.1\k-Wave\Scholte_final\Pressure');


Ux2=(sensor_data.ux_non_staggered);
Ux2=reshape(Ux2, [Nx, Ny,kgrid.Nt]);

Uy2=(sensor_data.uy_non_staggered);
Uy2=reshape(Uy2, [Nx, Ny,kgrid.Nt]);

Uz2=(sensor_data.uz_non_staggered);
Uz2=reshape(Uz2, [Nx, Ny,kgrid.Nt]);
p=sensor_data.uz_non_staggered;

Ux2_sq=(Ux2).*(Ux2);
Uy2_sq=(Uy2).*(Uy2);
Uz2_sq=(Uz2).*(Uz2);

% ux^2-uy^2
Ux2_diff=Ux2_sq-Uy2_sq-Uz2_sq;
Uy2_diff=Uy2_sq-Ux2_sq-Uz2_sq;
Uz2_diff=Uz2_sq-Ux2_sq-Uy2_sq;  % no need for2Dasz-derivative is not here.



%p=P.Pressure;
p=reshape(p, [Nx, Ny, kgrid.Nt]);
p2=p.*p;

% gradient calculation

%for Fx
UxUy=Ux2.*Uy2;
Uxy_y1_all = zeros(size(UxUy));
Uxy_x1_all = zeros(size(UxUy));

% Loop through each time step
for tIndex = 1:size(UxUy, 3)
    % Compute the gradient along x and y directions for the current time step
    [Uxy_y1,Uxy_x1] = gradient(UxUy(:, :, tIndex), dy, dx);
    
    % Store the results in the corresponding arrays
    Uxy_y1_all(:, :, tIndex) = Uxy_y1;
    Uxy_x1_all(:, :, tIndex) = Uxy_x1;
end

Ux2_y_all = zeros(size(Ux2_diff));
Ux2_x_all = zeros(size(Ux2_diff));

% Loop through each time step
for tIndex = 1:size(Ux2_diff, 3)
    % Compute the gradient along x and y directions for the current time step
    [Ux2_y,Ux2_x] = gradient(Ux2_diff(:, :, tIndex), dy, dx);
    
    % Store the results in the corresponding arrays
    Ux2_y_all(:, :, tIndex) = Ux2_y;
    Ux2_x_all(:, :, tIndex) = Ux2_x;
end

speed=medium.sound_speed(:,:,round(Nz/2));
density=medium.density(:,:,round(Nz/2));

Term_x1=density.*Uxy_y1_all;  % term_x1 is much lower than term x2
Term_x2=density.*(Ux2_x_all/2)+(p2./(2*density.*speed.^2));

%(density.*Uxy2_x_all/2)+(p2./(2*density.*speed.^2));
Fx2=rms((-Term_x1-Term_x2),3);

% for Fy

Uy2_y_all = zeros(size(Uy2_diff));
Uy2_x_all = zeros(size(Uy2_diff));

% Loop through each time step
for tIndex = 1:size(Uy2_diff, 3)
    % Compute the gradient along x and y directions for the current time step
    [Uy2_y,Uy2_x] = gradient(Uy2_diff(:, :, tIndex), dy, dx);
    
    % Store the results in the corresponding arrays
    Uy2_y_all(:, :, tIndex) = Uy2_y;
    Uy2_x_all(:, :, tIndex) = Uy2_x;
end
Term_y1=density.*Uxy_x1_all;  % term_x1 is much lower than term x2
Term_y2=density.*(Uy2_y_all/2)+(p2./(2*density.*speed.^2));
Fy2=rms((-Term_y1-Term_y2),3);


% for Fz

UzUx=Uz2.*Ux2;
Uzx_y1_all = zeros(size(UzUx));
Uzx_x1_all = zeros(size(UzUx));

for tIndex = 1:size(UzUx, 3)
    % Compute the gradient along x and y directions for the current time step
    [Uzx_y1,Uzx_x1] = gradient(UzUx(:, :, tIndex), dy, dx);
    
    % Store the results in the corresponding arrays
    Uzx_y1_all(:, :, tIndex) = Uzx_y1;
    Uzx_x1_all(:, :, tIndex) = Uzx_x1;
end

UzUy=Uz2.*Uy2;
Uzy_y1_all = zeros(size(UzUy));
Uzy_x1_all = zeros(size(UzUy));

for tIndex = 1:size(UzUy, 3)
    % Compute the gradient along x and y directions for the current time step
    [Uzy_y1,Uzy_x1] = gradient(UzUy(:, :, tIndex), dy, dx);
    
    % Store the results in the corresponding arrays
    Uzy_y1_all(:, :, tIndex) = Uzy_y1;
    Uzy_x1_all(:, :, tIndex) = Uzy_x1;
end


Term_z1=(density.*Uzx_x1_all);  % term_x1 is much lower than term x2
Term_z2=(density.*Uzy_y1_all); 
Fz2=rms((-Term_z1-Term_z2),3);

F_max = max([max(Fx2(:)), max(Fy2(:)), max(Fz2(:))]);
Fx2=Fx2./F_max;
Fy2=Fy2./F_max;
Fz2=Fz2./F_max;

fig = figure;
fig.OuterPosition = [100 100 1400 800];

% Define axis limits for all subplots
axis_limits = [min(kgrid.y_vec*1e3), max(kgrid.y_vec*1e3), min(kgrid.x_vec*1e3)+1.35, max(kgrid.x_vec*1e3)+1.35];
sfh1 = subplot(1, 3, 1);
 sfh1.Position = sfh1.Position - [-0.04 0 0.028 0];

imagesc(kgrid.y_vec*1e3, kgrid.x_vec*1e3+1.35, Fx2, [0, 1]);
set(gca, 'FontSize', 18, 'FontWeight', 'bold', 'XLim', axis_limits(1:2), 'YLim', axis_limits(3:4));
xlabel('x [mm]', 'FontWeight', 'bold', 'FontSize', 18);
ylabel('z [mm]', 'FontWeight', 'bold', 'FontSize', 18);
colormap(gca, 'jet');
title('fz', 'FontSize', 18);

sfh2 =subplot(1, 3, 2);
imagesc(kgrid.y_vec*1e3, kgrid.x_vec*1e3+1.35, Fy2, [0, 1]);
set(gca, 'FontSize', 18, 'FontWeight', 'bold', 'XLim', axis_limits(1:2), 'YLim', axis_limits(3:4));
xlabel('x [mm]', 'FontWeight', 'bold', 'FontSize', 18);
ylabel('z [mm]', 'FontWeight', 'bold', 'FontSize', 18);
colormap(gca, 'jet');
h = colorbar;
title('fx', 'FontSize', 18);

% Create a color bar for fz and fx combined
sfh3 =subplot(1, 3, 3);
imagesc(kgrid.y_vec*1e3, kgrid.x_vec*1e3+1.35, Fz2,[0, 1e-5]);
set(gca, 'FontSize', 18, 'FontWeight', 'bold', 'XLim', axis_limits(1:2), 'YLim', axis_limits(3:4));
xlabel('x [mm]', 'FontWeight', 'bold', 'FontSize', 18);
ylabel('z [mm]', 'FontWeight', 'bold', 'FontSize', 18);
colormap(gca, 'jet');
h = colorbar;
% set(h, 'Position', [0.92, 0.1, 0.02, 0.8]);  % Adjust the position as needed
title('fy', 'FontSize', 18);


%% Force plot with individual colorbar

fig = figure;
fig.OuterPosition = [100 100 400 800];

% Define axis limits for all subplots
axis_limits = [min(kgrid.y_vec*1e3), max(kgrid.y_vec*1e3), min(kgrid.x_vec*1e3)+1.35, max(kgrid.x_vec*1e3)+1.35];
%sfh1 = subplot(1, 3, 1);
% sfh1.Position = sfh1.Position - [-0.04 0 0.028 0];

imagesc(kgrid.y_vec*1e3, kgrid.x_vec*1e3+1.35, Fx3, [0, 1]);
set(gca, 'FontSize', 18, 'FontWeight', 'bold', 'XLim', axis_limits(1:2), 'YLim', axis_limits(3:4));
xlabel('x [mm]', 'FontWeight', 'bold', 'FontSize', 18);
ylabel('z [mm]', 'FontWeight', 'bold', 'FontSize', 18);
colormap(gca, 'jet');
h = colorbar;
title('fz', 'FontSize', 18);

%sfh2 =subplot(1, 3, 2);
fig = figure;
fig.OuterPosition = [100 100 400 800];

imagesc(kgrid.y_vec*1e3, kgrid.x_vec*1e3+1.35, Fy3, [0, 1]);
set(gca, 'FontSize', 18, 'FontWeight', 'bold', 'XLim', axis_limits(1:2), 'YLim', axis_limits(3:4));
xlabel('x [mm]', 'FontWeight', 'bold', 'FontSize', 18);
ylabel('z [mm]', 'FontWeight', 'bold', 'FontSize', 18);
colormap(gca, 'jet');
h = colorbar;
title('fx', 'FontSize', 18);

% Create a color bar for fz and fx combined
%sfh3 =subplot(1, 3, 3);
fig = figure;
fig.OuterPosition = [100 100 400 800];

imagesc(kgrid.y_vec*1e3, kgrid.x_vec*1e3+1.35, Fz3,[0, 1e-5]);
set(gca, 'FontSize', 18, 'FontWeight', 'bold', 'XLim', axis_limits(1:2), 'YLim', axis_limits(3:4));
xlabel('x [mm]', 'FontWeight', 'bold', 'FontSize', 18);
ylabel('z [mm]', 'FontWeight', 'bold', 'FontSize', 18);
colormap(gca, 'jet');
h = colorbar;
% set(h, 'Position', [0.92, 0.1, 0.02, 0.8]);  % Adjust the position as needed
title('fy', 'FontSize', 18);


%% vector plot (new)

% Assuming F is your force matrix of size 101x73

% Assuming kgrid.y_vec, kgrid.x_vec, and Fx1 are defined
%F=sqrt(Fx2.^2+Fy2.^2);
Fx=Fx2(161:336, 1:end);
Fy2(:,1:round(Ny/2))=-Fy2(:,1:round(Ny/2));
Fy=Fy2(161:336, 1:end);


%F = F(251:2:350, 51:2:150);
F = sqrt(Fx.^2+Fy.^2);
%F=F./max(F(:));

% Create the imagesc plot
figure;
%imagesc(F);
% Create a grid for the vector plot
%[X, Y] = meshgrid((1:size(F, 2)), 1:size(F, 1));

% x_axis=kgrid.x_vec(241:2:330)*1e3-3;
% y_axis=kgrid.y_vec(63:2:152)*1e3+0.1;
 x_axis=kgrid.x_vec(161:4:336)*1e3+1.43;
 y_axis=kgrid.y_vec(1:4:176)*1e3;
%[X, Y] = meshgrid(1:4:90, 1:4:90);
 %[X, Y] = meshgrid(1:4:90, 1:4:90);
 [X, Y] = meshgrid(x_axis, y_axis);


% Plot the force matrix using imagesc
imagesc(y_axis,x_axis, F);

colormap('jet'); % You can choose a colormap of your preference
colorbar; % Add a colorbar for reference

% Add labels and title
xlabel('X [mm]', 'FontWeight', 'bold',FontSize=15);
ylabel('Y [mm]','FontWeight', 'bold',FontSize=15);
title('Force vector (Second order approximation)', FontSize=24);

% Hold on to overlay the vector plot
  hold on;

U =Fy;


V =Fx;

% Assuming Fx and Fy are your x and y components of the force vectors
% You may need to adjust the scaling factor based on your data
quiver(X-0.075-1.43, Y+1.48, U(1:4:176, 1:4:176), V(1:4:176, 1:4:176), 'r','AutoScale', 'on', 'AutoScaleFactor', 1.4);  % 'w' sets the color of the arrows to white
%quiver(X+0.55, Y-0.5, U(1:2:90, 1:2:90), V(1:2:90, 1:2:90),'w','AutoScale', 'on', 'AutoScaleFactor', 0.6);  % 'w' sets the color of the arrows to white
% Hold off to stop overlaying
hold off;
% axis([-2.2 2.2 -2.8 1.5])

%% Figure 6

F1=sqrt(Fx1.^2+Fy1.^2);
F1_236=F1(236,:);
F2=sqrt(Fx2.^2+Fy2.^2);
F2_236=F2(236,:);
F3=sqrt(Fx3.^2+Fy3.^2);
F3_236=F3(236,:);

plot(F2_236,'Color', 'k', 'LineWidth', 2);
hold on
plot(F1_236,'Color', 'r', 'LineWidth', 2);
plot(F3_236,'Color', 'b', 'LineWidth', 2);
xlabel('Y (mm)', 'FontWeight', 'bold');
ylabel('Force (N)', 'FontWeight', 'bold');
title('Force Magnitude', 'FontWeight', 'bold');
legend('SO','QPW','APW');




%% Elastic simulation


clear medium;

Excitation='static';
PML_X_SIZE=10;
PML_Y_SIZE=10;

% New Grid points 
Nx = 256- 2*PML_X_SIZE;    % excluding PML layer, all Nx, Ny, Nz (including PML) are power of 2
Ny = 320 - 2*PML_Y_SIZE;   % broadened the horizon

%old grid points and time steps

%Nx1 = 150- 2*PML_X_SIZE;    % excluding PML layer, all Nx, Ny, Nz (including PML) are power of 2
%Ny1 = 75- 2*PML_Y_SIZE; 

% grid step size

dx=0.2e-3; %unit is meter
% dx=0.05e-3; %unit is meter
dy=dx;

%define top layer_water
cp1 = 1480;   % Longitudinal wave speed for tissue
cs1 = 0;      % shear wave speed
rho1 = 1000;  %density
alpha0_p1 = 0.002;        % absorption coefficient for water
alpha0_s1 = 0.002;

%define bottom layer_tissue
cp2 = 1540;    % Longitudinal wave speed
cs2 = 10;      % shear wave speed
rho2 = 1050;   %density
alpha0_p2 = 0.5;   % absorption coefficient 
alpha0_s2 = 0.5;   % absorption coefficient


%create k-space
kgrid = kWaveGrid(Nx, dx, Ny, dy);
cfl = 0.3; %increase it to accomodate computation time and memory
t_end =5500e-6;  % how long I want the elastic simulation (different than t_end used in fluid simulation)
%t_end = 270e-6;  % how long I want the elastic simulation (different than t_end used in fluid simulation)
kgrid.makeTime(cp1, cfl, t_end);


%Nt1=kgrid.Nt; % simulation time for current and previous are samee here
%signal
source_strength = 1;
% define position of heterogeneous slab
slab                = zeros(Nx, Ny);
%slab(Nx/4:end, :)   = 1;
slab(21:end, :)   = 1;

%medium properties
medium.sound_speed_compression            = cp1*ones(Nx, Ny);
medium.sound_speed_compression(slab==1) = cp2;
medium.sound_speed_shear                  = cs1*ones(Nx, Ny);
medium.sound_speed_shear(slab==1)       = cs2;
medium.density                            = rho1*ones(Nx, Ny);
medium.density(slab==1)                 = rho2;
medium.alpha_coeff_compression            = alpha0_p1*ones(Nx, Ny);
medium.alpha_coeff_compression(slab==1) = alpha0_p2;
medium.alpha_coeff_shear                  = alpha0_s1*ones(Nx, Ny);
medium.alpha_coeff_shear(slab==1)       = alpha0_s2;

%define sensor mask
sensor.mask = zeros(Nx, Ny);
sensor.mask(:,:) =1;
source.u_mask=sensor.mask;

%define sensor mask
sensor.mask = zeros(Nx, Ny);
sensor.mask(:,:) =1;
source.u_mask=sensor.mask;

Nt=kgrid.Nt;
% %Conversion of force to velocity for input (Static_excitation)
switch Excitation

case 'static'
Fx = zeros(Nx, Ny); 
Fy = zeros(Nx, Ny); 
%Fx(1:size(Fx1,1),1:size(Fx1,2))=Fx1(:,:);
%Fy(1:size(Fy1,1),1:size(Fy1,2))=Fy1(:,:);

Fx(1:Nx,1:115)=Fx3(181:416,62:end);
Fy(1:Nx,1:115)=Fy3(181:416,62:end);
 Ux1=Fx.*dx./(2*medium.density.*medium.sound_speed_compression);
 Ux1=reshape(Ux1, [Nx*Ny, 1]); %k-wave considers only this format
 Uy1=Fy*dx./(2*medium.density.*medium.sound_speed_compression);
 Uy1=reshape(Uy1, [Nx*Ny, 1]);
 Ux1_new = repmat(Ux1, 1, 2000);
 Uy1_new = repmat(Uy1, 1, 2000);

%For dynamic excitation
case 'dynamic'
 Fx = zeros(Nx, Ny,size(Fx3,3)); 
 Fy = zeros(Nx, Ny,size(Fy3,3)); 
 Fx(1:size(Fx3,1),1:size(Fx3,2),:)=Fx3(:,:,:);
 Fy(1:size(Fy3,1),1:size(Fy3,2),:)=Fy3(:,:,:);

  Ux1_new=Fx.*dx./(2*medium.density.*medium.sound_speed_compression);
  Ux1_new=reshape(Ux1,[Nx*Ny,size(Fx1,3)]);
  Uy1_new=Fy.*dx./(2*medium.density.*medium.sound_speed_compression);
  Uy1_new=reshape(Uy1,[Nx*Ny,size(Fx1,3)]);

end
clear source
%define source and sensor mask

source.u_mask=sensor.mask;
%source for static excitation
%  source.ux=Ux1_new;  
%  source.uy=Uy1_new;
%source for dynamic excitation
source.ux=Ux1_new;  
 source.uy=Uy1_new;

input_args = {'PMLSize',[PML_X_SIZE, PML_Y_SIZE], 'PMLAlpha', 1, 'PlotPML', false, ...
    'PMLInside', true, 'PlotScale', [-1e-4 1e-4]*source_strength, ...
    'DisplayMask', 'off', 'DataCast', 'single','RecordMovie', false};

% record of the outputs
sensor.record = {'u','p'};

sensor_data_elastic3 = pstdElastic2D(kgrid, medium, source, sensor, input_args{:});

 Uz_final=sensor_data_elastic3.ux;
%save('Uz_final_APW.mat', 'Uz_final','-v7.3');
 
 %% video

 % Define the file name for the video
videoFileName = 'U_video2.avi';

% Create a VideoWriter object
writerObj = VideoWriter(videoFileName);

% Set the frame rate (adjust as needed)
writerObj.FrameRate = 20;

% Open the video file for writing
open(writerObj);

% Reshape the matrix
U = reshape(Uz_final, Nx, Ny, []);

% Create a figure
figure;

% Loop through each frame and add it to the video
for i = 1:100:kgrid.Nt
    % Display the frame
    imagesc(U(:,:,i), [-5e-6, 5e-6]);
    colormap('jet');
    
    % Capture the frame as an image
    frame = getframe(gcf);
    
    % Write the frame to the video
    writeVideo(writerObj, frame);
    
    % Pause for a short duration
    pause(0.05);
end

% Close the video file
close(writerObj);

% Display a message when the video is saved
disp(['Video saved as ' videoFileName]);

%% Velocity component plot and wave guide for all three time steps (colorbar at third plot)

% Add tight_subplot function to your MATLAB path
% You can find the function here: https://www.mathworks.com/matlabcentral/fileexchange/27991-tight_subplot-nh-nw-gap-margins-shepfig
% Download the function and place it in your working directory or any directory on your MATLAB path
sensor_data_elastic3.ux=Uz_final;
% Define ii_range based on your requirements
%ii_range = [10200, 35200, 99200];
ii_range = 35200;

% Initialize a cell array to store the image filenames
image_filenames = cell(1, length(ii_range));

% Create a figure using tight_subplot
fig = figure;
fig.OuterPosition = [100 100 1400 500];

% Define the number of rows and columns
nRows = 1;
nCols = 3;

% Define the gap between subplots
gap = 0.04;

% Create tight subplots
ax = tight_subplot(nRows, nCols, [gap, gap], 0.2, 0.2);

for i = 1:length(ii_range)
    ii = ii_range(i);
    
    ux_ii = squeeze(sensor_data_elastic3.ux(:, ii));
    ux_ii = reshape(ux_ii, Nx, Ny);

    % Use the subplot handle
    subplot(ax(i));
    imagesc(kgrid.y_vec * 1e3*0.03/0.2+3.84, kgrid.x_vec* 1e3*0.03/0.2+3, ux_ii, [-3e-4, 3e-4]);
    set(gca, 'FontSize', 18, 'FontWeight', 'bold');
    xlabel('x [mm]', 'FontWeight', 'bold', 'FontSize', 18);
    ylabel('z [mm]', 'FontWeight', 'bold', 'FontSize', 18);
    axis image;
    colormap('jet');
    
    % Add colorbar only for the third subplot
   ii=round(ii*kgrid.dt*1e6);
    title([num2str(ii) ' {\mu}s'], 'FontSize', 22);
  
    axis equal;
    axis tight;
% Add colorbar only for the third subplot
% Add colorbar only for the third subplot
% Add colorbar only for the third subplot
if i == 3
    h = colorbar;
    ylabel(h, '[m/s]');
    
    % Manually adjust colorbar size to match subplot height
    cbPos = h.Position;
    cbPos(1) = ax(3).Position(1) + ax(3).Position(3) + 0.05; % Adjust the gap as needed
    cbPos(3) = 0.015; % Set the desired width
    cbPos(2) = ax(3).Position(2); % Align with the bottom of the subplot
    cbPos(4) = 0.6; % Match the height of the subplot
    h.Position = cbPos;
   
end


    
    % Save the image
    filename = fullfile('C:\Users\BARL\Desktop\Shear Wave Elastography\Acosutic_Sim\After Proposal data\Trial', ['image_' num2str(ii) '.png']);
    %saveas(gcf, filename);
    
    % Store the filename for future reference
    image_filenames{i} = filename;
end

%% Wave speed calculation (Wave guide scholte)
sensor_data_elastic3.ux=Uz_final;

%Scholte wave

time_step=10200;
ux_time_step = squeeze(sensor_data_elastic3.ux(:,time_step));
ux_time_step = reshape( ux_time_step, Nx, Ny);
ux_time_step=ux_time_step(25,27:end);
[pks,locs] = findpeaks(ux_time_step);
[max_peak, max_index] = max(pks);
max_peak_location = locs(max_index);

time_step2=35200;
ux_time_step2 = squeeze(sensor_data_elastic3.ux(:,time_step2));
ux_time_step2 = reshape( ux_time_step2, Nx, Ny);
ux_time_step2=ux_time_step2(25,27:end);
[pks2,locs2] = findpeaks(ux_time_step2);
[max_peak2, max_index2] = max(pks2);
max_peak_location2 = locs2(max_index2);


 time_step3=99200;

 ux_time_step3 = squeeze(sensor_data_elastic3.ux(:,time_step3));
 ux_time_step3 = reshape( ux_time_step3, Nx, Ny);
 ux_time_step3=ux_time_step3(25,27:end);
[pks3,locs3] = findpeaks(ux_time_step3);
[max_peak3, max_index3] = max(pks3);
max_peak_location3 = locs3(max_index3);

distance=abs(max_peak_location3-max_peak_location2)*dx;
time=abs(time_step3-time_step2)*kgrid.dt;
velocity_scholte=distance/time;




fig = figure;
fig.OuterPosition = [100 100 700 700];
% subplot(1, 2, 1);
tt= (1:length(ux_time_step3)) * dx*1e3*0.03/0.2;
plot(tt,ux_time_step,'LineWidth',3);
hold on;
plot(tt,ux_time_step2,'LineWidth',3);
plot(tt,ux_time_step3,'LineWidth',3);
set(gca, 'FontSize', 18) % Adjust the font size as needed
set(gca, 'FontWeight', 'bold')
xlabel('x [mm]', 'FontWeight', 'bold',FontSize=18);
ylabel('Uz [m/s]','FontWeight', 'bold',FontSize=18);
% Set y-axis tick positions
% ytick_values = [-0.02, -0.0, 0.02, 0.04, 0.06, 0.08]; % Adjust the tick values as needed
% yticks(ytick_values);
legend('414 {\mu}s','1427 {\mu}s',' 4022 {\mu}s' );
title('Uz at 0.20 mm depth',FontSize=22)
% Set the aspect ratio to avoid distortion
set(gca, 'PlotBoxAspectRatio', [1,1,1]); 


% subplot(1, 2, 2);
% plot(tt,ux_time_step2,'LineWidth',3);
% set(gca, 'FontSize', 24) % Adjust the font size as needed
% set(gca, 'FontWeight', 'bold')
% xlabel('x [mm]', 'FontWeight', 'bold',FontSize=24);
% ylabel('Uz [m/s]','FontWeight', 'bold',FontSize=24);
% title('163 {\mu}s');
% 
% % Adjust figure properties for high quality
% set(gcf, 'Color', 'white'); % Set background color to white
% set(gcf, 'Renderer', 'painters'); % Use painters renderer for vector graphics

% Set the aspect ratio to avoid distortion
set(gca, 'PlotBoxAspectRatio', [1,1,1]); 
% Save the figure in high quality

saveas(gcf, 'Scholte_plot.jpg', 'jpg'); % Save as JPEG

% Shear wave

ux_time_step4s = squeeze(sensor_data_elastic3.ux(:,time_step));
ux_time_step4s = reshape( ux_time_step4s, Nx, Ny);
ux_time_step4s=ux_time_step4s(100,27:end);
[pks4s,locs4s] = findpeaks(ux_time_step);
[max_peak4s, max_index4s] = max(pks4s);
max_peak_location4s = locs4s(max_index4s);


ux_time_step5s = squeeze(sensor_data_elastic3.ux(:,time_step2));
ux_time_step5s = reshape( ux_time_step5s, Nx, Ny);
ux_time_step5s=ux_time_step5s(100,27:end);
[pks5s,locs5s] = findpeaks(ux_time_step5s);
[max_peak5s, max_index5s] = max(pks5s);
max_peak_location5s = locs5s(max_index5s);

ux_time_step6s = squeeze(sensor_data_elastic3.ux(:,time_step3));
ux_time_step6s = reshape( ux_time_step6s, Nx, Ny);
ux_time_step6s=ux_time_step6s(100,27:end);
[pks6s,locs6s] = findpeaks(ux_time_step6s);
[max_peak6s, max_index6s] = max(pks6s);
max_peak_location6s = locs6s(max_index6s);

distance2=abs(max_peak_location6s-max_peak_location4s)*dx;
time2=abs(time_step3-time_step)*kgrid.dt;
velocity_shear=distance2/time2;
ratio=velocity_scholte/velocity_shear;

fig = figure;
fig.OuterPosition = [100 100 700 700];
% subplot(1, 2, 1);
tt= (1:length(ux_time_step4s)) * dx*1e3*0.03/0.2;
plot(tt,ux_time_step4s,'LineWidth',3);
hold on;
plot(tt,ux_time_step5s,'LineWidth',3);
plot(tt,ux_time_step6s,'LineWidth',3);
set(gca, 'FontSize', 18) % Adjust the font size as needed
set(gca, 'FontWeight', 'bold')
xlabel('x [mm]', 'FontWeight', 'bold',FontSize=18);
ylabel('Uz [m/s]','FontWeight', 'bold',FontSize=18);
% Set y-axis tick positions
% ytick_values = [-0.02, -0.0, 0.02, 0.04, 0.06, 0.08]; % Adjust the tick values as needed
% yticks(ytick_values);
legend('414 {\mu}s','1427 {\mu}s',' 4022 {\mu}s' );
title('Uz at 2.30 mm depth',FontSize=22)
% Set the aspect ratio to avoid distortion
set(gca, 'PlotBoxAspectRatio', [1,1,1]); 




% Set the aspect ratio to avoid distortion
set(gca, 'PlotBoxAspectRatio', [1,1,1]); 
% Save the figure in high quality

saveas(gcf, 'Scholte_plot.jpg', 'jpg'); % Save as JPEG
%% for penetration depth
sensor_data_elastic3.ux=Uz_final;
MM=kgrid.y_vec * 1e3*0.03/0.2 ;
NN=kgrid.x_vec * 1e3*0.03/0.2+3.54;
% MM=kgrid.y_vec * 1e3 ;
% NN=kgrid.x_vec * 1e3+4;

time_step=10200;
%time_step=6200;
ux_time_step = squeeze(sensor_data_elastic3.ux(:,time_step));
ux_time_step = reshape( ux_time_step, Nx, Ny);
% ux_time_step=ux_time_step(1:end,136);
ux_time_step=ux_time_step(1:end,24); %3 MHz
% ux_time_step=ux_time_step(1:end,135); %6 MHz

time_step2=35200;
%time_step2=8200;
ux_time_step2 = squeeze(sensor_data_elastic3.ux(:,time_step2));
ux_time_step2 = reshape( ux_time_step2, Nx, Ny);
%ux_time_step2=ux_time_step2(1:end,169); %3 MHz
ux_time_step2=ux_time_step2(1:end,86); %6 MHz

time_step3=99200;
%time_step3=18200;
ux_time_step3 = squeeze(sensor_data_elastic3.ux(:,time_step3));
ux_time_step3 = reshape( ux_time_step3, Nx, Ny);
%ux_time_step3=ux_time_step3(1:end,256); %3 MHz
ux_time_step3=ux_time_step3(1:end,196);  %6 MHz

fig = figure;
fig.OuterPosition = [100 100 700 700];
%plot(NN(1:end),ux_time_step,'LineWidth',3)

plot(NN(1:end),ux_time_step2,'LineWidth',3)
hold on;
plot(NN(1:end),ux_time_step3,'LineWidth',3)
%xlim([-1, 9])
set(gca, 'FontSize', 22) % Adjust the font size as needed
set(gca, 'FontWeight', 'bold')
xlabel('z [mm]', 'FontWeight', 'bold',FontSize=22);
ylabel('Uz [m/s]','FontWeight', 'bold',FontSize=22);
legend('1427 {\mu}s','4022 {\mu}s');

%%% Penetration depth for frequencies

% fig = figure;
% fig.OuterPosition = [100 100 700 700];
% plot(NN(1:end),PD_3_MHz,'LineWidth',3)
% hold on;
% plot(NN(1:end),PD_6MHz,'LineWidth',3)
% 
% 
% xlim([-1, 9])
% set(gca, 'FontSize', 22) % Adjust the font size as needed
% set(gca, 'FontWeight', 'bold')
% xlabel('z [mm]', 'FontWeight', 'bold',FontSize=22);
% ylabel('Uz [m/s]','FontWeight', 'bold',FontSize=22);
% legend('3 MHz','6 MHz' );


%%% Beam_width for frequencies

% fig = figure;
% fig.OuterPosition = [100 100 700 700];
%beam_width_3=BW_3MHz(89, 109:end);
% beam_width_6=BW_6MHz(89, 109:end);
% plot(MM(109:end),beam_width_3,'LineWidth',3)
% hold on;
% plot(MM(109:end),beam_width_6,'LineWidth',3)

%%% PD for frequencies

% fig = figure;
% fig.OuterPosition = [100 100 700 700];
% plot(NN(1:end),PD_3MHZ_0,'LineWidth',3)
% hold on;
% plot(NN(1:end),PD_3mm,'LineWidth',3)
% plot(NN(1:end),PD_4mm,'LineWidth',3)
% 
% xlim([-1, 9])
% set(gca, 'FontSize', 22) % Adjust the font size as needed
% set(gca, 'FontWeight', 'bold')
% xlabel('z [mm]', 'FontWeight', 'bold',FontSize=22);
% ylabel('Uz [m/s]','FontWeight', 'bold',FontSize=22);
% legend('Interface','3 mm shallow','4 mm deep' );

%%% Beam_width for frequencies

fig = figure;
fig.OuterPosition = [100 100 700 700];
beam_width_S=BW_surface(89, 109:end);
beam_width_3=BW_3(89, 109:end);
beam_width_4=BW_4(109, 109:end);

plot(MM(109:end),beam_width_S,'LineWidth',3)
hold on;
plot(MM(109:end),beam_width_3,'LineWidth',3)
plot(MM(109:end),beam_width_4,'LineWidth',3)
xlim([0, 6])
set(gca, 'FontSize', 22) % Adjust the font size as needed
set(gca, 'FontWeight', 'bold')
xlabel('z [mm]', 'FontWeight', 'bold',FontSize=22);
ylabel('Uz [m/s]','FontWeight', 'bold',FontSize=22);
legend('Interface','3 mm shallow','4 mm deep' );


%% calculation of penetration depth considering 90% of maximum amplitude

% Normalize the curve
normalized_curve = ux_time_step2 / max(ux_time_step2(:));

% Find the location of the maximum amplitude
[max_amplitude, max_index] = max(normalized_curve);

% Set a threshold for 90% of the maximum amplitude
threshold = 0.1 * max_amplitude;

% Plot the normalized curve
figure;
plot(normalized_curve);
hold on;

% Draw a line at 10% of the maximum amplitude
line_position = 0.1* max(abs(normalized_curve));
line([1, length(normalized_curve)], [line_position, line_position], 'Color', 'r', 'LineWidth', 2);

% Find intervals where the curve crosses the line
crossing_intervals = find(diff(sign(normalized_curve - line_position)) ~= 0);

% Initialize array to store intersection points
intersection_x = [];

% Loop through each interval and find intersections
for i = 1:length(crossing_intervals)
    interval_start = crossing_intervals(i);
    interval_end = crossing_intervals(i) + 1;
    
    % Find intersection using fzero in the current interval
    x_intersection = fzero(@(x) interp1(1:length(normalized_curve), normalized_curve, x) - line_position, [interval_start, interval_end]);
    
    % Plot the intersection point
    scatter(x_intersection, line_position, 100, 'g', 'filled');
    
    % Add the intersection point to the array
    intersection_x = [intersection_x, x_intersection];
end

title('Normalized Curve with Intersection Points');
xlabel('X');
ylabel('Normalized Curve');

% Display the x values of the intersection points
disp('X values of the intersection points:');
disp(intersection_x);

penetration_depth=(intersection_x(2)-intersection_x(1))*dx*1e3*0.03/0.2;
%penetration_depth=(intersection_x(2)-intersection_x(1))*dx*1e3;
