"""Speed-up chart from the EXPLAIN ANALYZE evidence files."""
import re, pathlib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ev = pathlib.Path(__file__).resolve().parent / "evidence"

def times(path):
    out, key = {}, None
    for line in path.read_text().splitlines():
        m = re.match(r"=== (H\d+)( \(after\))?:", line.strip())
        if m:
            key = m.group(1) + ("mv" if m.group(2) else "")
        m = re.search(r"Execution Time: ([\d.]+) ms", line)
        if m and key:
            out[key] = float(m.group(1))
    return out

b, a = times(ev / "explain_before.txt"), times(ev / "explain_after.txt")
rows = [("H2 Guest by phone\n(2 indexes)", b["H2"], a["H2"]),
        ("H3 Arrivals\n(partial index)", b["H3"], a["H3"]),
        ("H4 Bill total\n(covering index)", b["H4"], a["H4"]),
        ("H5 Occupancy\n(materialised view)", b["H5"], a["H5mv"]),
        ("H1 Availability\n(already indexed)", b["H1"], a["H1"])]
labels = [r[0] for r in rows]
speed = [r[1] / r[2] for r in rows]

fig, ax = plt.subplots(figsize=(9, 4.5))
bars = ax.barh(labels, speed, color=["#1f6f8b"] * 4 + ["#9aa5ab"])
ax.set_xscale("log")
ax.axvline(1, color="black", linewidth=0.8)
ax.invert_yaxis()
ax.set_xlabel("Times faster after optimisation (log scale)")
ax.set_title("Savannah Crest Hotels: query speed-up")
for bar, (_, bt, at), s in zip(bars, rows, speed):
    ax.text(bar.get_width() * 1.1, bar.get_y() + bar.get_height() / 2,
            f"{s:.0f}x  ({bt:.2f} ms -> {at:.2f} ms)" if s >= 1.5 else f"no change ({bt:.2f} -> {at:.2f} ms)",
            va="center", fontsize=9)
ax.set_xlim(0.5, max(speed) * 20)
fig.tight_layout()
fig.savefig(ev / "speedup_chart.png", dpi=150)
print("Saved", ev / "speedup_chart.png")
