%% Walker Uydu Takımyıldızı Simülasyonu
% Parametreler: 800 km irtifa, 53° eğim, 5 düzlem, 7 uydu/düzlem
% Walker Delta: 35/5/2 (Toplam 35 uydu, 5 düzlem, faz=2)
%
% Kullanım: Doğrudan çalıştırın. Animasyon için oynat/durdur butonunu kullanın.

clear; clc; close all;

%% ===================== YÖRÜNGE PARAMETRELERİ =====================
RE      = 6371;          % Dünya yarıçapı [km]
h       = 800;           % İrtifa [km]
a       = RE + h;        % Yarı-büyük eksen [km]
inc     = 53;            % Eğim [derece]
ecc     = 0;             % Dış merkezlilik
omega   = 0;             % Perigee argümanı [derece]
N_planes = 5;            % Düzlem sayısı
N_sat    = 7;            % Düzlem başına uydu sayısı
F        = 2;            % Faz parametresi
N_total  = N_planes * N_sat;  % Toplam uydu sayısı

%% ===================== YÖRÜNGE HESABI =====================
mu  = 398600.4418;       % Gravitasyonel parametre [km^3/s^2]
T   = 2*pi*sqrt(a^3/mu); % Yörünge periyodu [s]
n   = 2*pi/T;            % Ortalama hareket [rad/s]

fprintf('=== Walker Takımyıldızı Bilgileri ===\n');
fprintf('Toplam Uydu: %d\n', N_total);
fprintf('İrtifa: %d km\n', h);
fprintf('Eğim: %.1f°\n', inc);
fprintf('Yörünge Periyodu: %.1f dakika\n', T/60);
fprintf('Yörünge Hızı: %.2f km/s\n', sqrt(mu/a));

%% ===================== BAŞLANGIÇ KONUMLARI (WALKER DELTA) =====================
% RAAN aralığı: düzlemler eşit aralıklı
% Faz farkı: F * 360 / N_total derece

RAAN_list = zeros(1, N_planes);
M0_matrix = zeros(N_planes, N_sat);

for p = 1:N_planes
    RAAN_list(p) = (p-1) * 360 / N_planes;
    for s = 1:N_sat
        M0_matrix(p,s) = (s-1) * 360/N_sat + (p-1)*F*360/N_total;
    end
end

%% ===================== RENK PALETİ =====================
plane_colors = [
    0.20, 0.80, 1.00;   % Cyan
    1.00, 0.40, 0.20;   % Turuncu
    0.40, 1.00, 0.40;   % Yeşil
    1.00, 0.85, 0.10;   % Sarı
    0.90, 0.20, 0.80;   % Mor
];

%% ===================== ŞEKİL VE DÜNYA HARİTASI =====================
fig = figure('Name', 'Walker Takımyıldızı Simülasyonu', ...
             'Color', [0.05 0.05 0.12], ...
             'Position', [50 50 1400 800], ...
             'NumberTitle', 'off');

% Ana eksen (dünya haritası)
ax = axes('Parent', fig, 'Position', [0.02 0.12 0.96 0.82]);
hold(ax, 'on');

% ---- Dünya haritası arka plan ----
ax.Color = [0.04 0.10 0.20];
ax.XColor = [0.4 0.5 0.6];
ax.YColor = [0.4 0.5 0.6];

% Kıta verileri (coastlines)
load coastlines;
plot(ax, coastlon, coastlat, 'Color', [0.50 0.65 0.75], 'LineWidth', 0.8);

% Izgara çizgileri
for lon_g = -180:30:180
    plot(ax, [lon_g lon_g], [-90 90], 'Color', [0.15 0.20 0.30], 'LineWidth', 0.4);
end
for lat_g = -90:30:90
    plot(ax, [-180 180], [lat_g lat_g], 'Color', [0.15 0.20 0.30], 'LineWidth', 0.4);
end

% Ekvatör ve meridyen vurgusu
plot(ax, [-180 180], [0 0], 'Color', [0.25 0.40 0.55], 'LineWidth', 1.0);
plot(ax, [0 0], [-90 90], 'Color', [0.25 0.40 0.55], 'LineWidth', 1.0);

xlim(ax, [-180 180]);
ylim(ax, [-90 90]);
xlabel(ax, 'Boylam (°)', 'Color', [0.7 0.8 0.9], 'FontSize', 11);
ylabel(ax, 'Enlem (°)', 'Color', [0.7 0.8 0.9], 'FontSize', 11);
title(ax, sprintf('Walker Delta Takımyıldızı  |  %d uydu / %d düzlem / Faz=%d  |  800 km, i=53°', ...
      N_total, N_planes, F), ...
      'Color', [0.9 0.95 1.0], 'FontSize', 13, 'FontWeight', 'bold');
ax.GridColor = [0.2 0.3 0.4];
ax.TickLabelInterpreter = 'none';
ax.FontSize = 9;
ax.XColor = [0.5 0.6 0.7];
ax.YColor = [0.5 0.6 0.7];

%% ===================== YÖRÜNGE İZLERİNİ ÇİZ =====================
theta_orbit = linspace(0, 2*pi, 500);

track_handles = cell(N_planes, N_sat);

for p = 1:N_planes
    RAAN = deg2rad(RAAN_list(p));
    inc_r = deg2rad(inc);
    
    for s = 1:N_sat
        M0 = deg2rad(M0_matrix(p,s));
        
        % Tam yörünge iz noktaları
        lons = zeros(1, length(theta_orbit));
        lats = zeros(1, length(theta_orbit));
        
        for k = 1:length(theta_orbit)
            nu = theta_orbit(k); % true anomaly = mean anomaly (ecc=0)
            
            % Perifocal -> ECI
            r_peri = a * [cos(nu); sin(nu); 0];
            
            % Dönüş matrisleri (313: RAAN, inc, omega)
            Rz_RAAN = [cos(RAAN) -sin(RAAN) 0; sin(RAAN) cos(RAAN) 0; 0 0 1];
            Rx_inc  = [1 0 0; 0 cos(inc_r) -sin(inc_r); 0 sin(inc_r) cos(inc_r)];
            Rz_om   = [cos(0) -sin(0) 0; sin(0) cos(0) 0; 0 0 1];
            
            r_eci = Rz_RAAN * Rx_inc * Rz_om * r_peri;
            
            lat_rad = asin(r_eci(3)/norm(r_eci));
            lon_rad = atan2(r_eci(2), r_eci(1));
            
            lats(k) = rad2deg(lat_rad);
            lons(k) = rad2deg(lon_rad);
        end
        
        % Yörünge izini çiz (kesintileri bul)
        d_lon = diff(lons);
        breaks = find(abs(d_lon) > 180);
        
        seg_start = 1;
        for b = 1:length(breaks)
            seg_end = breaks(b);
            plot(ax, lons(seg_start:seg_end), lats(seg_start:seg_end), ...
                 'Color', [plane_colors(p,:) 0.35], 'LineWidth', 0.9);
            seg_start = breaks(b)+1;
        end
        plot(ax, lons(seg_start:end), lats(seg_start:end), ...
             'Color', [plane_colors(p,:) 0.35], 'LineWidth', 0.9);
    end
end

%% ===================== UYDU GRAFİKLERİ (HAREKETLİ) =====================
sat_dot = gobjects(N_planes, N_sat);
trail_line = gobjects(N_planes, N_sat);
trail_lon = cell(N_planes, N_sat);
trail_lat = cell(N_planes, N_sat);
TRAIL_LEN = 60;

for p = 1:N_planes
    for s = 1:N_sat
        trail_lon{p,s} = [];
        trail_lat{p,s} = [];
        
        trail_line(p,s) = plot(ax, NaN, NaN, '-', ...
            'Color', [plane_colors(p,:) 0.7], 'LineWidth', 1.5);
        
        sat_dot(p,s) = plot(ax, NaN, NaN, 'o', ...
            'MarkerSize', 8, ...
            'MarkerFaceColor', plane_colors(p,:), ...
            'MarkerEdgeColor', 'white', ...
            'LineWidth', 1.2);
    end
end

%% ===================== AÇIKLAMA PANELİ =====================
legend_ax = axes('Parent', fig, 'Position', [0.02 0.01 0.55 0.09]);
legend_ax.Visible = 'off';
for p = 1:N_planes
    text(legend_ax, (p-1)*0.20 + 0.01, 0.5, ...
        sprintf('■ Düzlem %d  (RAAN=%.0f°)', p, RAAN_list(p)), ...
        'Color', plane_colors(p,:), 'FontSize', 9.5, 'FontWeight', 'bold', ...
        'Units', 'normalized');
end

% Bilgi paneli
info_ax = axes('Parent', fig, 'Position', [0.60 0.01 0.39 0.09]);
info_ax.Visible = 'off';
info_txt = text(info_ax, 0.0, 0.7, '', ...
    'Color', [0.8 0.9 1.0], 'FontSize', 10, ...
    'Units', 'normalized', 'FontName', 'Courier New');
time_txt = text(info_ax, 0.0, 0.2, '', ...
    'Color', [0.6 0.8 0.6], 'FontSize', 10, ...
    'Units', 'normalized', 'FontName', 'Courier New');

%% ===================== ANİMASYON =====================
dt      = 30;          % Zaman adımı [s]
t_end   = T;           % Bir tam tur
t_vec   = 0:dt:t_end;
frame   = 0;

fprintf('\nAnimasyon başlatılıyor... (Pencereyi kapatmak için X''e tıklayın)\n');

for t = t_vec
    if ~ishandle(fig); break; end
    frame = frame + 1;
    
    for p = 1:N_planes
        RAAN  = deg2rad(RAAN_list(p));
        inc_r = deg2rad(inc);
        
        for s = 1:N_sat
            M0 = deg2rad(M0_matrix(p,s));
            
            % Ortalama anomali -> Gerçek anomali (ecc=0 -> M=nu)
            M  = mod(M0 + n*t, 2*pi);
            nu = M;  % ecc=0
            
            % ECI konumu
            r_peri = a * [cos(nu); sin(nu); 0];
            Rz_RAAN = [cos(RAAN) -sin(RAAN) 0; sin(RAAN) cos(RAAN) 0; 0 0 1];
            Rx_inc  = [1 0 0; 0 cos(inc_r) -sin(inc_r); 0 sin(inc_r) cos(inc_r)];
            r_eci = Rz_RAAN * Rx_inc * r_peri;
            
            % Dünya dönüşü (GMST yaklaşımı)
            omega_E = 7.2921150e-5; % rad/s
            theta_E = omega_E * t;
            
            % ECEF'e çevir
            r_ecef = [cos(theta_E)*r_eci(1) + sin(theta_E)*r_eci(2);
                     -sin(theta_E)*r_eci(1) + cos(theta_E)*r_eci(2);
                      r_eci(3)];
            
            lat = rad2deg(asin(r_ecef(3)/norm(r_ecef)));
            lon = rad2deg(atan2(r_ecef(2), r_ecef(1)));
            
            % İz güncelle
            trail_lon{p,s}(end+1) = lon;
            trail_lat{p,s}(end+1) = lat;
            if length(trail_lon{p,s}) > TRAIL_LEN
                trail_lon{p,s} = trail_lon{p,s}(end-TRAIL_LEN+1:end);
                trail_lat{p,s} = trail_lat{p,s}(end-TRAIL_LEN+1:end);
            end
            
            % Grafikleri güncelle
            set(sat_dot(p,s), 'XData', lon, 'YData', lat);
            set(trail_line(p,s), 'XData', trail_lon{p,s}, 'YData', trail_lat{p,s});
        end
    end
    
    % Zaman bilgisi
    mins = floor(t/60);
    secs = mod(t, 60);
    set(info_txt, 'String', sprintf('İrtifa: 800 km  |  Eğim: 53°  |  Ecc: 0'));
    set(time_txt, 'String', sprintf('Simülasyon Zamanı: %02d:%02d  (Periyot: %.0f dk)', ...
        mins, secs, T/60));
    
    drawnow limitrate;
    pause(0.02);
end

fprintf('Simülasyon tamamlandı!\n');