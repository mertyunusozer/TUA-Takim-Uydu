import numpy as np
import matplotlib.pyplot as plt
from math import radians, sin, cos, acos, atan2, sqrt, pi, degrees

# --- SABİTLER ---
R_EARTH = 6371.0
MU_EARTH = 398600.4418
INCLINATION = radians(53)

TARGETS = {
    "ANKARA (Merkez)": (39.9, 32.8),
    "EDIRNE (Kuzeybatı)": (41.6, 26.5),
    "DATCA (Güneybatı)": (36.7, 27.4),
    "KARS (Kuzeydoğu)": (40.6, 43.1),
    "HAKKARI (Güneydoğu)": (37.5, 43.7)
}

COLORS = ["#2196F3", "#FF9800", "#4CAF50", "#F44336", "#9C27B0"]

def get_elevation_angle(sat_lat, sat_lon, target_lat, target_lon, altitude):
    d_lon = sat_lon - target_lon
    cos_zeta = sin(target_lat)*sin(sat_lat) + cos(target_lat)*cos(sat_lat)*cos(d_lon)
    cos_zeta = max(-1.0, min(1.0, cos_zeta))
    zeta = acos(cos_zeta)
    r_ratio = R_EARTH / (R_EARTH + altitude)
    return degrees(atan2(cos_zeta - r_ratio, sin(zeta)))

def compute_data(altitude=800, num_planes=5, sats_per_plane=7, phase_factor=1):
    print("Veriler hesaplanıyor...")
    total_sats = num_planes * sats_per_plane
    a = R_EARTH + altitude
    mean_motion = sqrt(MU_EARTH / a ** 3)
    time_steps = np.arange(0, 86400, 120)

    sats = []
    for p in range(num_planes):
        raan = (2 * pi * p) / num_planes
        for s in range(sats_per_plane):
            ta = (2 * pi * s) / sats_per_plane + (2 * pi * phase_factor * p) / total_sats
            sats.append({'raan': raan, 'ta': ta})

    results = {}
    for name, coords in TARGETS.items():
        t_lat, t_lon = map(radians, coords)
        max_elevations = []
        for t in time_steps:
            earth_rotation = (2 * pi / 86400) * t
            current_target_lon = t_lon + earth_rotation
            max_el = 0
            for sat in sats:
                current_ta = sat['ta'] + mean_motion * t
                sat_lat = np.arcsin(np.sin(INCLINATION) * np.sin(current_ta))
                sat_lon = sat['raan'] + np.arctan2(
                    np.cos(INCLINATION) * np.sin(current_ta),
                    np.cos(current_ta)
                )
                el = get_elevation_angle(sat_lat, sat_lon, t_lat, current_target_lon, altitude)
                if el > max_el:
                    max_el = el
            max_elevations.append(max_el)
        results[name] = np.array(max_elevations)

    print("Hesaplama tamamlandı!\n")
    return results, time_steps / 3600

# ── 1. KLASİK ZAMAN SERİSİ ──────────────────────────────────────────
def plot_time_series(results, time_hours, cfg):
    fig, ax = plt.subplots(figsize=(14, 7))
    for (name, elev), color in zip(results.items(), COLORS):
        ax.plot(time_hours, elev, label=name, color=color, alpha=0.8, linewidth=1.5)
    ax.axhline(y=10, color='r', linestyle='--', linewidth=2, label='10° Min. Sınır')
    ax.fill_between(time_hours, 0, 10, color='red', alpha=0.07, label='Kapsama Dışı Bölge')
    ax.set_title(f"24 Saatlik Maksimum Elevasyon Açısı\n{cfg}", fontsize=13)
    ax.set_xlabel("Zaman (Saat)")
    ax.set_ylabel("Elevasyon Açısı (°)")
    ax.set_ylim(0, 90)
    ax.set_xlim(0, 24)
    ax.set_xticks(np.arange(0, 25, 2))
    ax.set_yticks(np.arange(0, 91, 10))
    ax.grid(True, linestyle=':', alpha=0.6)
    ax.legend(loc="upper right", fontsize=9)
    plt.tight_layout()
    plt.savefig("1_zaman_serisi.png", dpi=150)
    plt.close()
    print("✅ 1_zaman_serisi.png kaydedildi")

# ── 2. KUTU GRAFİĞİ (BOX PLOT) ──────────────────────────────────────
def plot_boxplot(results, cfg):
    fig, ax = plt.subplots(figsize=(10, 7))
    data = [elev for elev in results.values()]
    labels = [n.replace(" (", "\n(") for n in results.keys()]
    bp = ax.boxplot(data, patch_artist=True, notch=False,
                    medianprops=dict(color='black', linewidth=2))
    for patch, color in zip(bp['boxes'], COLORS):
        patch.set_facecolor(color)
        patch.set_alpha(0.7)
    ax.axhline(y=10, color='r', linestyle='--', linewidth=2, label='10° Min. Sınır')
    ax.set_xticklabels(labels, fontsize=9)
    ax.set_ylabel("Elevasyon Açısı (°)")
    ax.set_ylim(0, 90)
    ax.set_yticks(np.arange(0, 91, 10))
    ax.set_title(f"Elevasyon Dağılımı — Kutu Grafiği\n{cfg}", fontsize=13)
    ax.grid(True, axis='y', linestyle=':', alpha=0.6)
    ax.legend(fontsize=9)
    plt.tight_layout()
    plt.savefig("2_kutu_grafigi.png", dpi=150)
    plt.close()
    print("✅ 2_kutu_grafigi.png kaydedildi")

# ── 3. CDF GRAFİĞİ ───────────────────────────────────────────────────
def plot_cdf(results, cfg):
    fig, ax = plt.subplots(figsize=(10, 7))
    for (name, elev), color in zip(results.items(), COLORS):
        sorted_el = np.sort(elev)
        cdf = np.arange(1, len(sorted_el)+1) / len(sorted_el) * 100
        ax.plot(sorted_el, cdf, label=name, color=color, linewidth=2)
    ax.axvline(x=10, color='r', linestyle='--', linewidth=2, label='10° Min. Sınır')
    ax.axhline(y=100, color='gray', linestyle=':', linewidth=1)
    ax.set_xlabel("Elevasyon Açısı (°)")
    ax.set_ylabel("Zaman Yüzdesi (%)")
    ax.set_xlim(0, 90)
    ax.set_ylim(0, 105)
    ax.set_xticks(np.arange(0, 91, 10))
    ax.set_yticks(np.arange(0, 101, 10))
    ax.set_title(f"Kümülatif Dağılım Fonksiyonu (CDF)\n{cfg}", fontsize=13)
    ax.grid(True, linestyle=':', alpha=0.6)
    ax.legend(loc="lower right", fontsize=9)

    # Açıklama notu
    ax.text(12, 15,
            "Grafik nasıl okunur:\nX=30° → Y=%80 ise\nzamanın %80'inde\naçı ≥ 30° demektir",
            fontsize=8, color='gray',
            bbox=dict(boxstyle='round', facecolor='white', alpha=0.7))
    plt.tight_layout()
    plt.savefig("3_cdf_grafigi.png", dpi=150)
    plt.close()
    print("✅ 3_cdf_grafigi.png kaydedildi")

# ── ANA ÇALIŞTIRMA ────────────────────────────────────────────────────
if __name__ == "__main__":
    ALT, PLANES, SPP, F = 800, 7, 5, 1
    CFG = f"Walker {PLANES*SPP}/{PLANES}/F={F} — İrtifa: {ALT}km"

    results, time_hours = compute_data(ALT, PLANES, SPP, F)

    plot_time_series(results, time_hours, CFG)
    plot_boxplot(results, CFG)
    plot_cdf(results, CFG)

    print("\n🎉 Tüm grafikler oluşturuldu!")
    print("  → 1_zaman_serisi.png")
    print("  → 2_kutu_grafigi.png")
    print("  → 3_cdf_grafigi.png")