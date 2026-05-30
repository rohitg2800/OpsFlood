import unittest

from backend.state_severity_matrix import get_state_severity_entry, severity_from_entry


class CWCGuardSemanticsTests(unittest.TestCase):
    def test_case_a_below_warning_rain_below_severe_never_critical(self):
        entry = get_state_severity_entry("Maharashtra")
        warning = float(entry["warning_level_m"])
        # Keep below warning; rainfall below region severe threshold (COASTAL severe=400)
        river_level = warning - 0.5
        rainfall_7d = 350.0

        # Use a peak that would otherwise push raw severity to CRITICAL (depth axis)
        # (Maharashtra peak critical=13.5)
        severity = severity_from_entry(
            peak_level_m=float(entry["peak_level_m"]["critical"]),
            rainfall_7d_mm=rainfall_7d,
            entry=entry,
            river_level_m=river_level,
        )

        self.assertIn(severity, {"LOW", "MODERATE", "SEVERE"})
        self.assertNotEqual(severity, "CRITICAL")

    def test_case_b_between_warning_and_danger_critical_capped_to_severe(self):
        entry = get_state_severity_entry("Maharashtra")
        warning = float(entry["warning_level_m"])
        danger = float(entry["danger_level_m"])

        # Between warning and danger allows up to SEVERE, not CRITICAL
        river_level = (warning + danger) / 2
        # Use high rainfall that would trigger CRITICAL on rainfall axis (COASTAL critical=600)
        rainfall_7d = float(getattr(entry, 'rainfall_7d_mm', entry["rainfall_7d_mm"]).get("critical")) if False else 650.0

        severity = severity_from_entry(
            peak_level_m=float(entry["peak_level_m"]["critical"]),
            rainfall_7d_mm=rainfall_7d,
            entry=entry,
            river_level_m=river_level,
        )

        self.assertNotEqual(severity, "CRITICAL")
        # At minimum the guard should not allow CRITICAL; SEVERE is allowed.
        self.assertIn(severity, {"LOW", "MODERATE", "SEVERE"})

    def test_case_c_at_or_above_hfl_critical_allowed(self):
        entry = get_state_severity_entry("Maharashtra")
        hfl = float(entry["hfl_m"])

        severity = severity_from_entry(
            peak_level_m=float(entry["peak_level_m"]["critical"]),
            rainfall_7d_mm=100.0,
            entry=entry,
            river_level_m=hfl,
        )
        # If peak axis is critical, guard should allow CRITICAL at HFL.
        self.assertEqual(severity, "CRITICAL")


if __name__ == "__main__":
    unittest.main()

