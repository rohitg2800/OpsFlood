"""
backend/train_bihar.py
Run: python -m backend.train_bihar
"""
import json, random
from .state_severity_matrix import classify_rainfall, state_flood_risk
from .wrd_bihar_scraper import BIHAR_STATIONS

rng = random.Random(42)

def _sample():
    st = rng.choice(BIHAR_STATIONS)
    rainfall = rng.random() * 200
    current  = st["low"] + rng.random() * (st["danger"] + 3 - st["low"])
    return {"station": st["name"], "rainfall": round(rainfall,1),
            "current": round(current,2), "danger": st["danger"],
            "label": state_flood_risk("Bihar", rainfall, current, st["danger"])}

if __name__ == "__main__":
    samples = [_sample() for _ in range(5000)]
    dist = {}
    for s in samples: dist[s["label"]] = dist.get(s["label"],0) + 1
    print(f"Total: {len(samples)}  Distribution: {json.dumps(dist)}")
    for mm, exp in [(10,"LIGHT"),(30,"MODERATE"),(70,"HEAVY"),(120,"VERY_HEAVY"),(200,"EXTREME")]:
        got = classify_rainfall("Bihar", mm)
        print(f"  {mm:>5} mm -> {got:<12} {'OK' if got==exp else 'FAIL expected '+exp}")
