"""
backend/state_severity_matrix.py — Bihar-corrected IMD rainfall thresholds
"""

RAINFALL_THRESHOLDS = {
    "Bihar":          {"extreme": 115.6, "very_heavy": 64.5, "heavy": 15.6, "moderate": 2.5},
    "Assam":          {"extreme": 204.4, "very_heavy": 115.6, "heavy": 64.5, "moderate": 15.6},
    "Odisha":         {"extreme": 115.6, "very_heavy": 64.5,  "heavy": 35.5, "moderate": 7.5},
    "Maharashtra":    {"extreme": 204.4, "very_heavy": 115.6, "heavy": 64.5, "moderate": 15.6},
    "Uttar Pradesh":  {"extreme": 115.6, "very_heavy": 64.5,  "heavy": 35.5, "moderate": 7.5},
    "West Bengal":    {"extreme": 115.6, "very_heavy": 64.5,  "heavy": 35.5, "moderate": 7.5},
    "Kerala":         {"extreme": 204.4, "very_heavy": 115.6, "heavy": 64.5, "moderate": 15.6},
    "DEFAULT":        {"extreme": 115.6, "very_heavy": 64.5,  "heavy": 35.5, "moderate": 7.5},
}

def classify_rainfall(state: str, rainfall_mm: float) -> str:
    t = RAINFALL_THRESHOLDS.get(state, RAINFALL_THRESHOLDS["DEFAULT"])
    if rainfall_mm >= t["extreme"]:    return "EXTREME"
    if rainfall_mm >= t["very_heavy"]: return "VERY_HEAVY"
    if rainfall_mm >= t["heavy"]:      return "HEAVY"
    if rainfall_mm >= t["moderate"]:   return "MODERATE"
    return "LIGHT"

def state_flood_risk(state: str, rainfall_mm: float, current_level: float, danger_level: float) -> str:
    rain_class  = classify_rainfall(state, rainfall_mm)
    level_ratio = current_level / danger_level if danger_level > 0 else 0.0
    score = {"EXTREME": 0.40, "VERY_HEAVY": 0.30, "HEAVY": 0.20, "MODERATE": 0.10, "LIGHT": 0.0}[rain_class]
    if level_ratio >= 1.0:    score += 0.45
    elif level_ratio >= 0.90: score += 0.35
    elif level_ratio >= 0.75: score += 0.20
    elif level_ratio >= 0.60: score += 0.10
    if score >= 0.70: return "CRITICAL"
    if score >= 0.45: return "HIGH"
    if score >= 0.25: return "MODERATE"
    return "LOW"
