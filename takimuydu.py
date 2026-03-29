import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import Patch
from math import radians, sin, cos, acos, atan2, sqrt, pi, degrees
import subprocess, sys

# --- GEREKLİ KÜTÜPHANELERİ YÜKLE ---
for pkg in ["geopandas", "shapely"]:
    try:
        __import__(pkg)
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", pkg, "-q"])

import geopandas as gpd
from shapely.geometry import Point

# --- SABİTLER ---
R_EARTH = 6371.0
MU_EARTH = 398600.4418
INCLINATION = radians(53)
MIN_EL = 10.0
ALT, PLANES, SPP, F, STEP = 800, 7, 5, 1, 10

# --- TÜRKİYE SINIRI (Natural Earth — resmi veri) ---
def get_turkey():
    print("Türkiye sınırı yükleniyor (Natural Earth)...")
    world = gpd.read_file(
        "https://naturalearth.s3.amazonaws.com/110m_cultural/ne_110m_admin_0_countries.zip"
    )
    turkey = world[world["ISO_A3"] == "TUR"].geometry.values[0]
    print("✅ Türkiye sınırı yüklendi")
    return turkey

# --- UYDU KONFİGÜRASYONU ---
def build_sats():
    total = PLANES * SPP
    sats = []
    for p in range(PLANES):
        raan = (2 * pi * p) / PLANES
        for s in range(SPP):
            ta = (2 * pi * s) / SPP + (2 * pi * F * p) / total
            sats.append({'raan': raan, 'ta': ta})
    return sats

def get_elevation_angle(sat_lat, sat_lon, t_lat, t_lon_cur, altitude):
    d_lon = sat_lon - t_lon_cur
    cos_zeta = sin(t_lat)*sin(sat_lat) + cos(t_lat)*cos(sat_lat)*cos(d_lon)
    cos_zeta = max(-1.0, min(1.0, cos_zeta))
    zeta = acos(cos_zeta)
    r_ratio = R_EARTH / (R_EARTH + altitude)
    return degrees(atan2(cos_zeta - r_ratio, sin(zeta)))

def analyze_point(lat_deg, lon_deg, sats, mean_motion, time_steps):
    t_lat = radians(lat_deg)
    t_lon = radians(lon_deg)
    outage_count = 0
    min_el = 999.0
    sum_el = 0.0

    for t in time_steps:
        earth_rot = (2 * pi / 86400) * t
        cur_lon = t_lon + earth_rot
        max_el = 0.0
        for sat in sats:
            cur_ta = sat['ta'] + mean_motion * t
            s_lat = np.arcsin(np.sin(INCLINATION) * np.sin(cur_ta))
            s_lon = sat['raan'] + np.arctan2(
                np.cos(INCLINATION) * np.sin(cur_ta),
                np.cos(cur_ta)
            )
            el = get_elevation_angle(s_lat, s_lon, t_lat, cur_lon, ALT)
            if el > max_el:
                max_el = el
        if max_el < MIN_EL:
            outage_count += 1
        if max_el < min_el:
            min_el = max_el
        sum_el += max_el

    outage_min = outage_count * STEP / 60
    avg_el = sum_el / len(time_steps)
    return min_el, avg_el, outage_min

# --- ANA ANALİZ ---
def run_analysis():
    turkey = get_turkey()

    # 0.5° ızgara — sadece Türkiye içindeki noktalar
    lons = np.arange(26.0, 45.0, 0.5)
    lats = np.arange(36.0, 42.5, 0.5)
    grid_points = [
        (lat, lon)
        for lat in lats for lon in lons
        if turkey.contains(Point(lon, lat))
    ]
    print(f"✅ {len(grid_points)} analiz noktası Türkiye içinde belirlendi\n")

    a = R_EARTH + ALT
    mean_motion = sqrt(MU_EARTH / a ** 3)
    sats = build_sats()
    time_steps = np.arange(0, 86400, STEP)

    results = []
    n = len(grid_points)
    for i, (lat, lon) in enumerate(grid_points):
        if (i + 1) % 20 == 0 or i == 0 or i == n - 1:
            print(f"  [{i+1:>3}/{n}] %{(i+1)/n*100:.0f} — ({lat:.1f}°N, {lon:.1f}°E)")
        min_el, avg_el, outage_min = analyze_point(
            lat, lon, sats, mean_motion, time_steps
        )
        results.append({
            'lat': lat, 'lon': lon,
            'min_el': min_el,
            'avg_el': avg_el,
            'outage_min': outage_min,
            'has_outage': outage_min > 0
        })

    return results, turkey

# --- GRAFİKLER ---
def plot_results(results, turkey):
    lats      = np.array([r['lat']        for r in results])
    lons      = np.array([r['lon']        for r in results])
    min_els   = np.array([r['min_el']     for r in results])
    avg_els   = np.array([r['avg_el']     for r in results])
    has_outage= np.array([r['has_outage'] for r in results])

    fig, axes = plt.subplots(1, 3, figsize=(21, 7))
    cfg = f"Walker {PLANES*SPP}/{PLANES}/F={F} — {ALT}km — {STEP}s Örnekleme"
    fig.suptitle(f"Türkiye Kapsama Analizi\n{cfg}", fontsize=14, fontweight='bold')

    def draw_turkey(ax):
        """Türkiye sınırını çiz — MultiPolygon desteğiyle."""
        from shapely.geometry import MultiPolygon
        polys = list(turkey.geoms) if hasattr(turkey, 'geoms') else [turkey]
        for poly in polys:
            x, y = poly.exterior.xy
            ax.plot(x, y, 'k-', linewidth=1.5, zorder=5)
        ax.set_xlim(25.5, 45.0)
        ax.set_ylim(35.8, 42.5)
        ax.set_xlabel("Boylam (°E)", fontsize=10)
        ax.set_ylabel("Enlem (°N)", fontsize=10)
        ax.grid(True, linestyle=':', alpha=0.4)

    # ── 1. Minimum Elevasyon Haritası ──
    ax1 = axes[0]
    sc1 = ax1.scatter(lons, lats, c=min_els, cmap='RdYlGn',
                      vmin=0, vmax=45, s=60, marker='s', zorder=3)
    plt.colorbar(sc1, ax=ax1, label='Min Elevasyon (°)', shrink=0.85)
    ax1.set_title("Minimum Elevasyon Açısı\n(En kötü an)", fontsize=11)
    draw_turkey(ax1)

    # ── 2. Ortalama Elevasyon Haritası ──
    ax2 = axes[1]
    sc2 = ax2.scatter(lons, lats, c=avg_els, cmap='YlGn',
                      vmin=10, vmax=40, s=60, marker='s', zorder=3)
    plt.colorbar(sc2, ax=ax2, label='Ort Elevasyon (°)', shrink=0.85)
    ax2.set_title("Ortalama Elevasyon Açısı\n(Genel kapsama kalitesi)", fontsize=11)
    draw_turkey(ax2)

    # ── 3. Kesinti Haritası ──
    ax3 = axes[2]
    colors_map = ['#FF3333' if h else '#00C853' for h in has_outage]
    ax3.scatter(lons, lats, c=colors_map, s=60, marker='s', zorder=3)
    no_out   = int(np.sum(~has_outage))
    with_out = int(np.sum(has_outage))
    legend_els = [
        Patch(facecolor='#00C853', label=f'Kesintisiz ({no_out} nokta)'),
        Patch(facecolor='#FF3333', label=f'Kesintili ({with_out} nokta)')
    ]
    ax3.legend(handles=legend_els, loc='lower right', fontsize=9)
    ax3.set_title("Kesinti Durumu\n(Kırmızı = Kesinti Var)", fontsize=11)
    draw_turkey(ax3)

    plt.tight_layout()
    plt.savefig("turkiye_kapsama_haritasi.png", dpi=150, bbox_inches='tight')
    plt.close()
    print("✅ turkiye_kapsama_haritasi.png kaydedildi")

# --- ÖZET ---
def print_summary(results):
    total    = len(results)
    no_out   = sum(1 for r in results if not r['has_outage'])
    with_out = total - no_out
    print("\n" + "="*55)
    print("TÜRKIYE KAPSAMA ÖZET RAPORU")
    print(f"Walker {PLANES*SPP}/{PLANES}/F={F} — {ALT}km — {STEP}s Örnekleme")
    print("="*55)
    print(f"Toplam analiz noktası : {total}")
    print(f"Kesintisiz            : {no_out}  (%{no_out/total*100:.1f})")
    print(f"Kesintili             : {with_out}  (%{with_out/total*100:.1f})")
    print(f"Ort. Min Elevasyon    : {np.mean([r['min_el'] for r in results]):.1f}°")
    print(f"Ort. Ortalama El.     : {np.mean([r['avg_el'] for r in results]):.1f}°")
    if with_out == 0:
        print("\n✅ TÜM NOKTALARDA KESİNTİSİZ BAĞLANTI SAĞLANDI!")
    else:
        print(f"\n⚠️  Kesintili noktalar:")
        for r in sorted(results, key=lambda x: x['outage_min'], reverse=True):
            if r['has_outage']:
                print(f"  ({r['lat']:.1f}°N, {r['lon']:.1f}°E) → {r['outage_min']:.1f} dk")
    print("="*55)

# --- ÇALIŞTIR ---
if __name__ == "__main__":
    results, turkey = run_analysis()
    print_summary(results)
    plot_results(results, turkey)
    print("\n🎉 Analiz tamamlandı → turkiye_kapsama_haritasi.png")