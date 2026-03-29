%% Walker Uydu Takımyıldızı Simülasyonu (7x5, Faz=1)
clear; clc; close all;

%% ===================== YÖRÜNGE PARAMETRELERİ =====================
RE      = 6371;          % Dünya yarıçapı [km]
h       = 800;           % İrtifa [km]
a       = RE + h;        % Yarı-büyük eksen [km]
inc     = 53;            % Eğim [derece]
ecc     = 0;             % Dış merkezlilik
omega   = 0;             % Perigee argümanı [derece]
N_planes = 7;            % Düzlem sayısı
N_sat    = 5;            % Düzlem başına uydu sayısı
F        = 1;            % Faz parametresi 
N_total  = N_planes * N_sat;  % Toplam uydu sayısı

%% ===================== YÖRÜNGE HESABI =====================
mu  = 398600.4418;       % Gravitasyonel parametre [km^3/s^2]
T   = 2*pi*sqrt(a^3/mu); % Yörünge periyodu [s]
n   = 2*pi/T;            % Ortalama hareket [rad/s]

fprintf('=== Walker Takımyıldızı Bilgileri ===\n');
fprintf('Toplam Uydu: %d\n', N_total);
fprintf('Düzlem x Uydu: %d x %d\n', N_planes, N_sat);
fprintf('Yörünge Periyodu: %.1f dakika\n', T/60);

%% ===================== BAŞLANGIÇ KONUMLARI =====================
RAAN_list = zeros(1, N_planes);
M0_matrix = zeros(N_planes, N_sat);
for p = 1:N_planes
    RAAN_list(p) = (p-1) * 360 / N_planes;
    for s = 1:N_sat
        % Walker Delta Faz Formülü
        M0_matrix(p,s) = (s-1) * 360/N_sat + (p-1)*F*360/N_total;
    end
end

%% ===================== RENK PALETİ (7 Düzlem) =====================
plane_colors = [
    0.20, 0.80, 1.00;   % Cyan
    1.00, 0.40, 0.20;   % Turuncu
    0.40, 1.00, 0.40;   % Yeşil
    1.00, 0.85, 0.10;   % Sarı
    0.90, 0.20, 0.80;   % Mor
    0.20, 1.00, 0.80;   % Turkuaz
    1.00, 0.40, 0.60;   % Pembe
];

%% ===================== ŞEKİL VE HARİTA =====================
fig = figure('Name', 'Walker Takımyıldızı Simülasyonu', ...
             'Color', [0.05 0.05 0.12], ...
             'Position', [50 50 1200 700], ...
             'NumberTitle', 'off');

ax = axes('Parent', fig, 'Position', [0.05 0.15 0.90 0.80]);
hold(ax, 'on');
ax.Color = [0.04 0.10 0.20];

% Kıta verileri
load coastlines;
plot(ax, coastlon, coastlat, 'Color', [0.50 0.65 0.75], 'LineWidth', 1);

xlim(ax, [-180 180]);
ylim(ax, [-90 90]);
grid(ax, 'on');
ax.GridColor = [0.2 0.3 0.4];
ax.XColor = [0.5 0.6 0.7]; ax.YColor = [0.5 0.6 0.7];

title(ax, sprintf('Walker Delta %d/%d/%d (35 Uydu, 7 Düzlem, Faz 1)', N_total, N_planes, F), ...
      'Color', 'w', 'FontSize', 12);

%% ===================== YÖRÜNGE İZLERİ VE NESNELER =====================
sat_dot = gobjects(N_planes, N_sat);
trail_line = gobjects(N_planes, N_sat);
trail_lon = cell(N_planes, N_sat);
trail_lat = cell(N_planes, N_sat);
TRAIL_LEN = 40;

theta_orbit = linspace(0, 2*pi, 200);
for p = 1:N_planes
    RAAN = deg2rad(RAAN_list(p));
    inc_r = deg2rad(inc);
    
    lons_p = zeros(1, length(theta_orbit));
    lats_p = zeros(1, length(theta_orbit));
    
    for k = 1:length(theta_orbit)
        nu = theta_orbit(k);
        r_peri = a * [cos(nu); sin(nu); 0];
        Rz_RAAN = [cos(RAAN) -sin(RAAN) 0; sin(RAAN) cos(RAAN) 0; 0 0 1];
        Rx_inc  = [1 0 0; 0 cos(inc_r) -sin(inc_r); 0 sin(inc_r) cos(inc_r)];
        r_eci = Rz_RAAN * Rx_inc * r_peri;
        lats_p(k) = rad2deg(asin(r_eci(3)/norm(r_eci)));
        lons_p(k) = rad2deg(atan2(r_eci(2), r_eci(1)));
    end
    
    d_lon = diff(lons_p);
    idx = find(abs(d_lon) > 180);
    start_idx = 1;
    for i = 1:length(idx)
        plot(ax, lons_p(start_idx:idx(i)), lats_p(start_idx:idx(i)), 'Color', [plane_colors(p,:) 0.2]);
        start_idx = idx(i)+1;
    end
    plot(ax, lons_p(start_idx:end), lats_p(start_idx:end), 'Color', [plane_colors(p,:) 0.2]);

    for s = 1:N_sat
        trail_lon{p,s} = []; trail_lat{p,s} = [];
        trail_line(p,s) = plot(ax, NaN, NaN, '-', 'Color', [plane_colors(p,:) 0.6], 'LineWidth', 1.2);
        sat_dot(p,s) = plot(ax, NaN, NaN, 'o', 'MarkerFaceColor', plane_colors(p,:), ...
            'MarkerEdgeColor', 'w', 'MarkerSize', 6);
    end
end

%% ===================== BİLGİ PANELLERİ =====================
info_ax = axes('Parent', fig, 'Position', [0.05 0.02 0.90 0.1], 'Visible', 'off');
time_txt = text(info_ax, 0.5, 0.2, '', 'Color', 'w', 'HorizontalAlignment', 'center', 'FontName', 'Courier');

%% ===================== ANİMASYON DÖNGÜSÜ =====================
dt = 40; 
t_total = T; 
omega_E = 7.2921150e-5; % Dünya dönüş hızı

for t = 0:dt:t_total 
    if ~ishandle(fig); break; end
    
    theta_E = omega_E * t; % Dünya dönüş açısı
    
    for p = 1:N_planes
        RAAN_rad = deg2rad(RAAN_list(p));
        inc_rad  = deg2rad(inc);
        
        for s = 1:N_sat
            M_rad = deg2rad(M0_matrix(p,s)) + n*t;
           
            r_peri = a * [cos(M_rad); sin(M_rad); 0];
            Rz_RAAN = [cos(RAAN_rad) -sin(RAAN_rad) 0; sin(RAAN_rad) cos(RAAN_rad) 0; 0 0 1];
            Rx_inc  = [1 0 0; 0 cos(inc_rad) -sin(inc_rad); 0 sin(inc_rad) cos(inc_rad)];
            r_eci = Rz_RAAN * Rx_inc * r_peri;
            
            r_ecef = [cos(theta_E)*r_eci(1) + sin(theta_E)*r_eci(2);
                     -sin(theta_E)*r_eci(1) + cos(theta_E)*r_eci(2);
                      r_eci(3)];
            
            lat = rad2deg(asin(r_ecef(3)/norm(r_ecef)));
            lon = rad2deg(atan2(r_ecef(2), r_ecef(1)));
           
            trail_lon{p,s}(end+1) = lon;
            trail_lat{p,s}(end+1) = lat;
            if length(trail_lon{p,s}) > TRAIL_LEN
                trail_lon{p,s}(1) = []; trail_lat{p,s}(1) = [];
            end
            
            set(sat_dot(p,s), 'XData', lon, 'YData', lat);
            
            if max(abs(diff(trail_lon{p,s}))) < 180
                set(trail_line(p,s), 'XData', trail_lon{p,s}, 'YData', trail_lat{p,s});
            else
                set(trail_line(p,s), 'XData', NaN, 'YData', NaN); 
            end
        end
    end
   
    set(time_txt, 'String', sprintf('Süre: %02d:%02d / Periyot: %.0f dk', floor(t/60), mod(t,60), T/60));
    drawnow limitrate;
    pause(0.01);
end