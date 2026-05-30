import unittest

from backend.state_severity_matrix import (
    get_state_severity_entry,
    build_effective_state_entry,
    severity_from_entry,
)


class StationThresholdsTests(unittest.TestCase):
    def test_station_telemetry_overrides_warning_danger_and_caps_critical(self):
        """If station danger is higher than state danger, CRITICAL must be capped.

        Example motivating case:
          state default danger ~= 12.5, but station danger ~= 17.5
          river_level ~ 15.08 should allow SEVERE (<= danger) but not CRITICAL.
        """
        state = "andhra pradesh"
        base = get_state_severity_entry(state)

        telemetry_node = {
            "warning_level": 16.5,
            "danger_level": 17.5,
        }

        effective = build_effective_state_entry(state, telemetry_node)

        self.assertAlmostEqual(float(effective["warning_level_m"]), 16.5)
        self.assertAlmostEqual(float(effective["danger_level_m"]), 17.5)
        # Ensure we increased HFL if base hfl was lower than danger.
        self.assertGreaterEqual(float(effective["hfl_m"]), float(effective["danger_level_m"]))

        severity = severity_from_entry(
            peak_level_m=float(effective["peak_level_m"]["critical"]),
            rainfall_7d_mm=float(base["rainfall_7d_mm"]["critical"]),
            entry=effective,
            river_level_m=15.08,
        )

        # river_level 15.08 is below danger 17.5 and below hfl -> should not allow CRITICAL
        self.assertNotEqual(severity, "CRITICAL")
        self.assertIn(severity, {"LOW", "MODERATE", "SEVERE"})

    def test_no_telemetry_falls_back_to_state_matrix(self):
        state = "andhra pradesh"
        base = get_state_severity_entry(state)
        effective = build_effective_state_entry(state, station_telemetry=None)
        self.assertEqual(float(effective["warning_level_m"]), float(base["warning_level_m"]))
        self.assertEqual(float(effective["danger_level_m"]), float(base["danger_level_m"]))
        self.assertEqual(float(effective["hfl_m"]), float(base["hfl_m"]))


if __name__ == "__main__":
    unittest.main()

