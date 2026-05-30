"""
tests/test_bihar_severity_matrix.py

Unit tests for STATE_SEVERITY_MATRIX Bihar entry and severity_from_entry().

Scope
-----
- Bihar matrix entry completeness
- severity_from_entry() produces the right label at every threshold boundary
- Canonical regression: Bihar peak=13.5 m + rain=580 mm  → CRITICAL
- danger_level_override_guard Bihar-specific rules
- normalize_state_name() handles common aliases
- get_state_severity_entry() fallback behaviour
- All 36 states/UTs carry required keys
"""

import unittest

from backend.state_severity_matrix import (
    STATE_SEVERITY_MATRIX,
    DEFAULT_STATE_ENTRY,
    danger_level_override_guard,
    get_state_severity_entry,
    normalize_state_name,
    severity_from_entry,
)


class TestBiharEntry(unittest.TestCase):
    """Bihar STATE_SEVERITY_MATRIX entry structure and value checks."""

    def setUp(self):
        self.entry = get_state_severity_entry("bihar")

    # ── Completeness ────────────────────────────────────────────────────────
    def test_bihar_entry_present(self):
        self.assertIn("bihar", STATE_SEVERITY_MATRIX)

    def test_required_keys_present(self):
        required = {
            "region", "peak_level_m", "rainfall_7d_mm",
            "danger_level_m", "warning_level_m", "hfl_m",
            "primary_rivers", "vulnerable_districts", "notes",
        }
        for key in required:
            self.assertIn(key, self.entry, msg=f"Missing key: {key}")

    def test_threshold_sub_keys(self):
        for field in ("peak_level_m", "rainfall_7d_mm"):
            for sub in ("moderate", "severe", "critical"):
                self.assertIn(sub, self.entry[field], msg=f"{field}[{sub}] missing")

    # ── Value sanity ────────────────────────────────────────────────────────
    def test_bihar_region_is_plains(self):
        self.assertEqual(self.entry["region"], "PLAINS")

    def test_peak_level_ordering(self):
        pk = self.entry["peak_level_m"]
        self.assertLess(pk["moderate"], pk["severe"])
        self.assertLess(pk["severe"],   pk["critical"])

    def test_rainfall_ordering(self):
        rn = self.entry["rainfall_7d_mm"]
        self.assertLess(rn["moderate"], rn["severe"])
        self.assertLess(rn["severe"],   rn["critical"])

    def test_warning_below_danger(self):
        self.assertLess(
            float(self.entry["warning_level_m"]),
            float(self.entry["danger_level_m"]),
        )

    def test_danger_below_hfl(self):
        self.assertLess(
            float(self.entry["danger_level_m"]),
            float(self.entry["hfl_m"]),
        )

    def test_bihar_peak_critical_threshold(self):
        """Bihar CWC-calibrated critical peak is 13.2 m."""
        self.assertAlmostEqual(self.entry["peak_level_m"]["critical"], 13.2, places=1)

    def test_bihar_rain_critical_threshold(self):
        """Bihar calibrated critical 7-day rainfall is 560 mm."""
        self.assertAlmostEqual(self.entry["rainfall_7d_mm"]["critical"], 560.0, places=0)

    def test_bihar_danger_level(self):
        """Bihar CWC danger level is 12.0 m."""
        self.assertAlmostEqual(float(self.entry["danger_level_m"]), 12.0, places=1)

    def test_bihar_hfl(self):
        """Bihar HFL is 13.8 m."""
        self.assertAlmostEqual(float(self.entry["hfl_m"]), 13.8, places=1)


class TestSeverityFromEntryBihar(unittest.TestCase):
    """severity_from_entry() boundary tests using Bihar thresholds."""

    def setUp(self):
        self.entry = get_state_severity_entry("bihar")
        self.pk = self.entry["peak_level_m"]
        self.rn = self.entry["rainfall_7d_mm"]

    def _sev(self, peak, rain, river=None):
        return severity_from_entry(
            peak_level_m=peak,
            rainfall_7d_mm=rain,
            entry=self.entry,
            river_level_m=river,
        )

    # ── LOW boundary ────────────────────────────────────────────────────────
    def test_low_both_axes_below_moderate(self):
        self.assertEqual(
            self._sev(self.pk["moderate"] - 0.5, self.rn["moderate"] - 10),
            "LOW",
        )

    # ── MODERATE boundary ───────────────────────────────────────────────────
    def test_moderate_peak_at_threshold(self):
        sev = self._sev(self.pk["moderate"], self.rn["moderate"] - 10)
        self.assertIn(sev, {"MODERATE", "LOW"})  # peak axis hits moderate floor

    def test_moderate_rain_at_threshold(self):
        sev = self._sev(self.pk["moderate"] - 0.5, self.rn["moderate"])
        self.assertIn(sev, {"MODERATE", "LOW"})

    def test_moderate_both_axes_just_above(self):
        sev = self._sev(self.pk["moderate"] + 0.1, self.rn["moderate"] + 5)
        self.assertIn(sev, {"MODERATE", "SEVERE"})  # at least moderate
        self.assertNotEqual(sev, "LOW")

    # ── SEVERE boundary ─────────────────────────────────────────────────────
    def test_severe_at_peak_severe_threshold(self):
        sev = self._sev(self.pk["severe"], self.rn["severe"] + 10)
        self.assertIn(sev, {"SEVERE", "CRITICAL"})

    def test_severe_rain_axis(self):
        sev = self._sev(self.pk["severe"] + 0.1, self.rn["severe"])
        self.assertIn(sev, {"SEVERE", "CRITICAL"})
        self.assertNotEqual(sev, "LOW")
        self.assertNotEqual(sev, "MODERATE")

    # ── CRITICAL boundary ───────────────────────────────────────────────────
    def test_canonical_regression_critical(self):
        """
        Canonical Bihar regression: peak 13.5 m + 7d rain 580 mm → CRITICAL.
        This is the primary scenario from TODO.md that was failing before the fix.
        """
        sev = self._sev(13.5, 580.0)
        self.assertEqual(sev, "CRITICAL", msg="Bihar 13.5m + 580mm must be CRITICAL")

    def test_critical_both_axes_above_threshold(self):
        sev = self._sev(self.pk["critical"] + 0.1, self.rn["critical"] + 20)
        self.assertEqual(sev, "CRITICAL")

    def test_critical_peak_only(self):
        """Peak above critical threshold alone should be enough for CRITICAL."""
        sev = self._sev(self.pk["critical"] + 0.5, self.rn["moderate"])
        # Peak axis alone drives CRITICAL regardless of rain
        self.assertEqual(sev, "CRITICAL")

    def test_critical_rain_only(self):
        """Rain above critical threshold alone should be enough for CRITICAL."""
        sev = self._sev(self.pk["moderate"], self.rn["critical"] + 10)
        self.assertEqual(sev, "CRITICAL")


class TestDangerLevelGuardBihar(unittest.TestCase):
    """danger_level_override_guard() Bihar-specific Option-A rules."""

    def setUp(self):
        self.entry = get_state_severity_entry("bihar")
        self.warning = float(self.entry["warning_level_m"])  # 10.2
        self.danger  = float(self.entry["danger_level_m"])   # 12.0
        self.hfl     = float(self.entry["hfl_m"])            # 13.8
        self.rn_crit = float(self.entry["rainfall_7d_mm"]["critical"])  # 560
        self.rn_sev  = float(self.entry["rainfall_7d_mm"]["severe"])    # 390

    def test_below_warning_low_rain_caps_at_moderate(self):
        result = danger_level_override_guard(
            severity="CRITICAL",
            river_level_m=self.warning - 1.0,
            rainfall_7d_mm=self.rn_sev - 50,
            entry=self.entry,
        )
        self.assertEqual(result, "MODERATE")

    def test_below_warning_high_rain_caps_at_severe(self):
        result = danger_level_override_guard(
            severity="CRITICAL",
            river_level_m=self.warning - 0.5,
            rainfall_7d_mm=self.rn_sev + 50,
            entry=self.entry,
        )
        self.assertEqual(result, "SEVERE")

    def test_between_warning_and_danger_caps_at_severe(self):
        mid = (self.warning + self.danger) / 2
        result = danger_level_override_guard(
            severity="CRITICAL",
            river_level_m=mid,
            rainfall_7d_mm=self.rn_crit,
            entry=self.entry,
        )
        self.assertEqual(result, "SEVERE")

    def test_at_danger_level_caps_at_severe(self):
        result = danger_level_override_guard(
            severity="CRITICAL",
            river_level_m=self.danger,
            rainfall_7d_mm=self.rn_crit,
            entry=self.entry,
        )
        self.assertEqual(result, "SEVERE")

    def test_at_hfl_allows_critical(self):
        result = danger_level_override_guard(
            severity="CRITICAL",
            river_level_m=self.hfl,
            rainfall_7d_mm=self.rn_crit,
            entry=self.entry,
        )
        self.assertEqual(result, "CRITICAL")

    def test_guard_never_raises_severity(self):
        """Guard is a cap only — it must never increase severity."""
        result = danger_level_override_guard(
            severity="LOW",
            river_level_m=self.hfl + 5.0,
            rainfall_7d_mm=self.rn_crit + 200,
            entry=self.entry,
        )
        self.assertEqual(result, "LOW")


class TestNormalizeAndFallback(unittest.TestCase):
    """normalize_state_name() aliases and DEFAULT_STATE_ENTRY fallback."""

    def test_alias_orissa_to_odisha(self):
        self.assertEqual(normalize_state_name("Orissa"), "odisha")

    def test_alias_nct_delhi(self):
        self.assertEqual(normalize_state_name("NCT of Delhi"), "delhi")

    def test_alias_jk(self):
        self.assertEqual(normalize_state_name("J&K"), "jammu and kashmir")

    def test_unknown_state_returns_default(self):
        result = get_state_severity_entry("atlantis")
        self.assertEqual(result["region"], DEFAULT_STATE_ENTRY["region"])

    def test_case_insensitive_lookup(self):
        e1 = get_state_severity_entry("Bihar")
        e2 = get_state_severity_entry("BIHAR")
        self.assertEqual(e1["danger_level_m"], e2["danger_level_m"])


class TestAllStatesHaveRequiredKeys(unittest.TestCase):
    """Every entry in STATE_SEVERITY_MATRIX must have the full required key set."""

    REQUIRED = {
        "region", "peak_level_m", "rainfall_7d_mm",
        "danger_level_m", "warning_level_m", "hfl_m",
        "primary_rivers", "vulnerable_districts", "notes",
    }
    THRESHOLD_KEYS = {"moderate", "severe", "critical"}

    def test_all_entries_complete(self):
        for state, entry in STATE_SEVERITY_MATRIX.items():
            with self.subTest(state=state):
                for key in self.REQUIRED:
                    self.assertIn(key, entry, msg=f"{state}: missing '{key}'")
                for field in ("peak_level_m", "rainfall_7d_mm"):
                    for sub in self.THRESHOLD_KEYS:
                        self.assertIn(
                            sub, entry[field],
                            msg=f"{state}: {field}[{sub}] missing",
                        )

    def test_all_warning_below_danger(self):
        for state, entry in STATE_SEVERITY_MATRIX.items():
            with self.subTest(state=state):
                w = float(entry["warning_level_m"] or 0)
                d = float(entry["danger_level_m"]  or 0)
                if w > 0 and d > 0:
                    self.assertLess(w, d, msg=f"{state}: warning >= danger")

    def test_all_danger_below_hfl(self):
        for state, entry in STATE_SEVERITY_MATRIX.items():
            with self.subTest(state=state):
                d = float(entry["danger_level_m"] or 0)
                h = float(entry["hfl_m"]          or 0)
                if d > 0 and h > 0:
                    self.assertLess(d, h, msg=f"{state}: danger >= hfl")


if __name__ == "__main__":
    unittest.main()
