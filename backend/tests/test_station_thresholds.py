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
        self.assertGreaterEqual(float(effective["hfl_m"]), float(effective["danger_level_m"]))

        severity = severity_from_entry(
            peak_level_m=float(effective["peak_level_m"]["critical"]),
            rainfall_7d_mm=float(base["rainfall_7d_mm"]["critical"]),
            entry=effective,
            river_level_m=15.08,
        )

        # river_level 15.08 < danger 17.5 < hfl → must NOT be CRITICAL
        self.assertNotEqual(severity, "CRITICAL")
        self.assertIn(severity, {"LOW", "MODERATE", "SEVERE"})

    def test_no_telemetry_falls_back_to_state_matrix(self):
        """Without station telemetry, effective entry must equal the state matrix defaults."""
        state = "andhra pradesh"
        base = get_state_severity_entry(state)
        effective = build_effective_state_entry(state, station_telemetry=None)
        self.assertEqual(float(effective["warning_level_m"]), float(base["warning_level_m"]))
        self.assertEqual(float(effective["danger_level_m"]), float(base["danger_level_m"]))
        self.assertEqual(float(effective["hfl_m"]), float(base["hfl_m"]))

    def test_bihar_station_danger_higher_than_state_default_caps_critical(self):
        """Bihar: elevated station danger must prevent CRITICAL when river < station danger."""
        # Bihar state default danger ≈ 12.0 m; simulate a Kosi basin station at 14.0 m
        state = "bihar"
        telemetry_node = {"warning_level": 11.9, "danger_level": 14.0}
        effective = build_effective_state_entry(state, telemetry_node)

        self.assertAlmostEqual(float(effective["danger_level_m"]), 14.0)
        self.assertGreaterEqual(float(effective["hfl_m"]), float(effective["danger_level_m"]))

        # river_level 13.5 is above state default danger (12.0) but below station danger (14.0)
        # → Option-A guard must cap severity at SEVERE or below
        severity = severity_from_entry(
            peak_level_m=13.5,
            rainfall_7d_mm=560.0,
            entry=effective,
            river_level_m=13.5,
        )
        self.assertNotEqual(severity, "CRITICAL")
        self.assertIn(severity, {"LOW", "MODERATE", "SEVERE"})

    def test_river_at_or_above_hfl_allows_critical(self):
        """river_level_m >= hfl_m must allow CRITICAL (Option-A guard Rule 1)."""
        state = "bihar"
        effective = build_effective_state_entry(state, station_telemetry=None)
        hfl = float(effective["hfl_m"])

        severity = severity_from_entry(
            peak_level_m=float(effective["peak_level_m"]["critical"]),
            rainfall_7d_mm=float(effective["rainfall_7d_mm"]["critical"]),
            entry=effective,
            river_level_m=hfl + 0.1,   # at/above HFL → CRITICAL allowed
        )
        self.assertEqual(severity, "CRITICAL")

    def test_severity_from_entry_low_baseline(self):
        """Sanity: low water level + low rainfall must always be LOW."""
        state = "bihar"
        entry = get_state_severity_entry(state)
        severity = severity_from_entry(
            peak_level_m=10.5,
            rainfall_7d_mm=200.0,
            entry=entry,
        )
        self.assertEqual(severity, "LOW")

    def test_severity_from_entry_critical_baseline(self):
        """Sanity: high water level + heavy rainfall must be CRITICAL when above HFL."""
        state = "bihar"
        entry = get_state_severity_entry(state)
        hfl = float(entry["hfl_m"])

        severity = severity_from_entry(
            peak_level_m=float(entry["peak_level_m"]["critical"]),
            rainfall_7d_mm=float(entry["rainfall_7d_mm"]["critical"]),
            entry=entry,
            river_level_m=hfl + 0.5,
        )
        self.assertEqual(severity, "CRITICAL")


if __name__ == "__main__":
    unittest.main()
