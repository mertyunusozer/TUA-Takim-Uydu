%% 3D Uydu Yörüngesi Simülasyonu — Dünya Texture + Zoom Düzeltmeli
clear; clc; close all;

%% ── PARAMETRELER ─────────────────────────────────────────────────────────
NUM_PLANES     = 5;
SATS_PER_PLANE = 7;
INCLINATION    = 53 * pi / 180;
EARTH_R        = 6371;
ORBIT_R        = 6371 + 1200;
PERIOD         = 5400;
TRAIL_LEN      = 15;
DT             = 60;

COLORS = [
    1.00  0.27  0.27;
    1.00  0.67  0.00;
    0.27  1.00  0.53;
    0.27  0.80  1.00;
    0.80  0.53  1.00;
];

%% ── TEXTURE İNDİR ────────────────────────────────────────────────────────
texFile = "C:\Users\pc\Desktop\2k_earth_daymap.jpg";

if isfile(texFile)
    img = imread(texFile);
    img = flipud(img);
    % Çok büyükse küçült (performans için)
    if size(img,2) > 2048
        img = imresize(img, [1024 2048]);
    end
    fprintf('Texture yuklendi: %dx%d piksel\n', size(img,2), size(img,1));
else
    error('Texture dosyasi bulunamadi: %s\nLutfen dosya yolunu kontrol et.', texFile);
end

%% ── ŞEKİL ────────────────────────────────────────────────────────────────
fig = figure('Name','Uydu Sim', 'Color','k', ...
             'Position',[60 50 1200 720], ...
             'NumberTitle','off', ...
             'KeyPressFcn',   @keyHandler, ...
             'WindowScrollWheelFcn', @scrollZoom);

ax = axes('Parent',fig, ...
          'Color','k', ...
          'XColor','none','YColor','none','ZColor','none', ...
          'DataAspectRatio',[1 1 1], ...
          'Projection','perspective', ...
          'Clipping','off');        % <── ZOOM'DA KAYBOLMAYI ÖNLER
hold(ax,'on');
view(ax, 40, 22);
lim = ORBIT_R * 1.4;
axis(ax,[-lim lim -lim lim -lim lim]);
set(ax,'ClippingStyle','rectangle');  % ekstra güvenlik

% Işık (güneş)
light('Position',[4e4 1e4 2e4],'Style','infinite','Color',[1.0 0.97 0.88]);
lighting(ax,'gouraud');

%% ── YILDIZLAR ────────────────────────────────────────────────────────────
rng(42);
nS = 800;
starR = lim * 4;          % çok uzakta → zoom'da kaybolmaz
sT = acos(2*rand(1,nS)-1);
sP = 2*pi*rand(1,nS);
sBr = 0.4 + 0.6*rand(1,nS);
for k = 1:nS
    plot3(ax, starR*sin(sT(k))*cos(sP(k)), ...
              starR*sin(sT(k))*sin(sP(k)), ...
              starR*cos(sT(k)), '.', ...
        'Color',[sBr(k) sBr(k) min(1,sBr(k)+0.1)], ...
        'MarkerSize', 1+round(sBr(k)*2));
end

%% ── DÜNYA KÜRESİ ─────────────────────────────────────────────────────────
[xs,ys,zs] = sphere(96);

if ~isempty(texFile) && isfile(texFile)
    img = imread(texFile);
    img = flipud(img);
    % Texture boyutunu sınırla (hız için)
    if size(img,1) > 1024
        img = imresize(img, [1024 2048]);
    end
    earthSurf = surf(ax, xs*EARTH_R, ys*EARTH_R, zs*EARTH_R, ...
        'CData',          img, ...
        'FaceColor',      'texturemap', ...
        'EdgeColor',      'none', ...
        'FaceLighting',   'gouraud', ...
        'AmbientStrength', 0.25, ...
        'DiffuseStrength', 0.85, ...
        'SpecularStrength',0.25, ...
        'SpecularExponent',20, ...
        'Clipping',       'off');   % <── KRİTİK: küreni kesmez
else
    % Yedek — mavi yerine yeşil/mavi prosedürel
    cmap = earthColormap();
    earthSurf = surf(ax, xs*EARTH_R, ys*EARTH_R, zs*EARTH_R, ...
        'CData',          zs, ...   % enleme göre renk
        'FaceColor',      'interp', ...
        'EdgeColor',      'none', ...
        'FaceLighting',   'gouraud', ...
        'Clipping',       'off');
    colormap(ax, cmap);
    clim(ax,[-1 1]);
end

% Atmosfer halkası
surf(ax, xs*EARTH_R*1.018, ys*EARTH_R*1.018, zs*EARTH_R*1.018, ...
    'FaceColor',[0.3 0.65 1.0], ...
    'EdgeColor','none', ...
    'FaceAlpha',0.055, ...
    'FaceLighting','none', ...
    'Clipping','off');

% Ekvator referans çizgisi
th = linspace(0,2*pi,300);
plot3(ax, EARTH_R*cos(th), EARTH_R*sin(th), zeros(1,300), ...
    'Color',[0.4 0.7 1.0 0.3],'LineWidth',0.6,'LineStyle','--');

%% ── YÖRÜNGELERİ ÇİZ ─────────────────────────────────────────────────────
ang = linspace(0,2*pi,250);
for p = 1:NUM_PLANES
    RAAN = (p-1)/NUM_PLANES*2*pi;
    [fx,fy,fz] = orbitXYZ(ang,RAAN,INCLINATION,ORBIT_R);
    plot3(ax,fx,fy,fz,'-', ...
        'Color',[COLORS(p,:) 0.40],'LineWidth',1.1,'Clipping','off');
end

%% ── UYDU & İZ NESNELERİ ─────────────────────────────────────────────────
satH   = gobjects(NUM_PLANES, SATS_PER_PLANE);
trailH = gobjects(NUM_PLANES, SATS_PER_PLANE);
trailBuf = zeros(NUM_PLANES, SATS_PER_PLANE, TRAIL_LEN, 3);

for p = 1:NUM_PLANES
    for s = 1:SATS_PER_PLANE
        pos = getSatPos(p,s,0,NUM_PLANES,SATS_PER_PLANE,INCLINATION,ORBIT_R,PERIOD);
        trailBuf(p,s,:,:) = repmat(pos,TRAIL_LEN,1);
        satH(p,s) = plot3(ax,pos(1),pos(2),pos(3),'o', ...
            'MarkerSize',5, ...
            'MarkerFaceColor',COLORS(p,:), ...
            'MarkerEdgeColor','w', ...
            'LineWidth',0.7, ...
            'Clipping','off');      % <── uydular kesilmez
        trailH(p,s) = plot3(ax,pos(1),pos(2),pos(3),'-', ...
            'Color',[COLORS(p,:) 0.2],'LineWidth',1.3,'Clipping','off');
    end
end

%% ── BAŞLIK & BİLGİ ───────────────────────────────────────────────────────
title(ax, sprintf('Uydu Sim  |  %dx%d = %d uydu  |  i=53 deg  |  e=0', ...
    NUM_PLANES,SATS_PER_PLANE,NUM_PLANES*SATS_PER_PLANE), ...
    'Color','w','FontSize',11,'FontWeight','bold');

infoTxt = text(ax,-lim*0.95,lim*0.95,lim*0.95,'', ...
    'Color','w','FontSize',9,'VerticalAlignment','top','FontName','Courier New');

text(ax,lim*0.95,-lim*0.95,-lim*0.95, ...
    'Space:Dur  |  < > Hiz  |  Scroll:Zoom  |  Q:Cikis', ...
    'Color',[0.5 0.8 1],'FontSize',8, ...
    'HorizontalAlignment','right','VerticalAlignment','bottom','FontName','Courier New');

legend(ax,[satH(1,1) satH(2,1) satH(3,1) satH(4,1) satH(5,1)], ...
    {'Duzlem 1','Duzlem 2','Duzlem 3','Duzlem 4','Duzlem 5'}, ...
    'TextColor','w','Color',[0.03 0.05 0.1],'EdgeColor',[0.3 0.4 0.6], ...
    'Location','northeast','FontSize',8);

%% ── DURUM ────────────────────────────────────────────────────────────────
setappdata(fig,'paused',false);
setappdata(fig,'speed',1);
setappdata(fig,'quit',false);
setappdata(fig,'axLim',lim);

simTime  = 0;
earthAng = 0;

fprintf('Basladi — Space:Dur  < >:Hiz  Scroll:Zoom  Q:Cikis\n');

%% ── ANA DÖNGÜ ────────────────────────────────────────────────────────────
while ishandle(fig) && ~getappdata(fig,'quit')

    if ~getappdata(fig,'paused')
        sp = getappdata(fig,'speed');
        simTime  = simTime + DT*sp;
        earthAng = earthAng + (DT*sp/86400)*2*pi;

        cosA = cos(earthAng); sinA = sin(earthAng);

        % Dünya döndür
        set(earthSurf, ...
            'XData',(xs*cosA - ys*sinA)*EARTH_R, ...
            'YData',(xs*sinA + ys*cosA)*EARTH_R, ...
            'ZData', zs*EARTH_R);

        % Uyduları güncelle
        for p = 1:NUM_PLANES
            for s = 1:SATS_PER_PLANE
                pos = getSatPos(p,s,simTime,NUM_PLANES,SATS_PER_PLANE, ...
                                INCLINATION,ORBIT_R,PERIOD);
                set(satH(p,s),'XData',pos(1),'YData',pos(2),'ZData',pos(3));
                trailBuf(p,s,:,:) = circshift(squeeze(trailBuf(p,s,:,:)),1,1);
                trailBuf(p,s,1,:) = pos;
                buf = squeeze(trailBuf(p,s,:,:));
                set(trailH(p,s),'XData',buf(:,1),'YData',buf(:,2),'ZData',buf(:,3));
            end
        end

        e = mod(floor(simTime),86400);
        set(infoTxt,'String',sprintf('T+ %02d:%02d:%02d  Hiz:x%g', ...
            floor(e/3600),floor(mod(e,3600)/60),mod(e,60),sp));
    end

    drawnow limitrate;
    pause(0.025);
end
fprintf('Bitti.\n');

%% ════════════════════════════════════════════════════════════════════════
%  YARDIMCI FONKSİYONLAR
%% ════════════════════════════════════════════════════════════════════════

function [fx,fy,fz] = orbitXYZ(angle,RAAN,incl,R)
    px=cos(angle); py=sin(angle); pz=zeros(size(angle));
    ry= py*cos(incl)-pz*sin(incl);
    rz= py*sin(incl)+pz*cos(incl);
    fx=(px*cos(RAAN)-ry*sin(RAAN))*R;
    fy=(px*sin(RAAN)+ry*cos(RAAN))*R;
    fz= rz*R;
end

function pos = getSatPos(p,s,t,nP,nS,incl,R,T)
    RAAN=(p-1)/nP*2*pi;
    angle=(s-1)/nS*2*pi+(t/T)*2*pi;
    [fx,fy,fz]=orbitXYZ(angle,RAAN,incl,R);
    pos=[fx,fy,fz];
end

function scrollZoom(fig,ev)
    ax  = gca;
    xl  = xlim(ax);
    cur = (xl(2)-xl(1))/2;
    if ev.VerticalScrollCount > 0
        cur = cur * 1.15;
    else
        cur = cur / 1.15;
    end
    cur = max(cur, 1500);    % min zoom sınırı
    cur = min(cur, 6e4);     % max zoom sınırı
    cx = mean(xlim(ax)); cy = mean(ylim(ax)); cz = mean(zlim(ax));
    xlim(ax,[cx-cur cx+cur]);
    ylim(ax,[cy-cur cy+cur]);
    zlim(ax,[cz-cur cz+cur]);
end

function keyHandler(~,ev)
    f=gcf;
    switch ev.Key
        case 'space'
            setappdata(f,'paused',~getappdata(f,'paused'));
        case 'period'
            v=getappdata(f,'speed');
            setappdata(f,'speed',min(v*2,128));
            fprintf('Hiz: x%g\n',min(v*2,128));
        case 'comma'
            v=getappdata(f,'speed');
            setappdata(f,'speed',max(v/2,0.125));
            fprintf('Hiz: x%g\n',max(v/2,0.125));
        case 'q'
            setappdata(f,'quit',true);
    end
end

function cmap = earthColormap()
    % Texture yoksa: okyanus mavisi + kara yeşili
    cmap = [
        0.05 0.20 0.50;   % derin okyanus
        0.10 0.35 0.65;   % sığ okyanus
        0.20 0.55 0.30;   % kıyı/bitki
        0.25 0.60 0.25;   % orman
        0.55 0.50 0.30;   % çöl/step
        0.80 0.75 0.65;   % dağ
        0.95 0.97 1.00;   % kar/buz
    ];
    % 256 renge interpolasyon
    x   = linspace(0,1,size(cmap,1));
    xi  = linspace(0,1,256);
    cmap = interp1(x,cmap,xi);
end