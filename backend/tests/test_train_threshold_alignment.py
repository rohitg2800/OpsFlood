"""
tests/test_train_threshold_alignment.py

Verifies that backend/train.py threshold constants are correctly derived
from STATE_SEVERITY_MATRIX (Bihar calibration) and that the synthetic
training data produced by get_training_data() is internally consistent.

These tests protect against future regressions where hardcoded values
could drift out of sync with the per-state matrix.
"""

import unittest
import numpy as np

from backend.train import (
    CALIBRATION_STATE,
    PK_MOD, PK_SEV, PK_CRIT, PK_HFL,
    RN_MOD, RN_SEV, RN_CRIT, RN_MAX,
    get_training_data,
)
from backend.state_severity_matrix import get_state_severity_entry


class TestCalibrationConstants(unittest.TestCase):
    """train.py exported constants must match the Bihar matrix exactly."""

    def setUp(self):
        self.entry = get_state_severity_entry(CALIBRATION_STATE)
        self.pk = self.entry["peak_level_m"]
        self.rn = self.entry["rainfall_7d_mm"]

    def test_calibration_state_is_bihar(self):
        self.assertEqual(CALIBRATION_STATE, "bihar")

    def test_pk_mod_matches_matrix(self):
        self.assertAlmostEqual(PK_MOD, float(self.pk["moderate"]), places=4)

    def test_pk_sev_matches_matrix(self):
        self.assertAlmostEqual(PK_SEV, float(self.pk["severe"]), places=4)

    def test_pk_crit_matches_matrix(self):
        self.assertAlmostEqual(PK_CRIT, float(self.pk["critical"]), places=4)

    def test_pk_hfl_matches_matrix(self):
        self.assertAlmostEqual(PK_HFL, float(self.entry["hfl_m"]), places=4)

    def test_rn_mod_matches_matrix(self):
        self.assertAlmostEqual(RN_MOD, float(self.rn["moderate"]), places=4)

    def test_rn_sev_matches_matrix(self):
        self.assertAlmostEqual(RN_SEV, float(self.rn["severe"]), places=4)

    def test_rn_crit_matches_matrix(self):
        self.assertAlmostEqual(RN_CRIT, float(self.rn["critical"]), places=4)

    def test_rn_max_is_140pct_of_crit(self):
        self.assertAlmostEqual(RN_MAX, RN_CRIT * 1.4, places=4)

    def test_constant_ordering_peak(self):
        """Thresholds must be strictly ascending."""
        self.assertLess(PK_MOD, PK_SEV)
        self.assertLess(PK_SEV, PK_CRIT)
        self.assertLess(PK_CRIT, PK_HFL)

    def test_constant_ordering_rain(self):
        self.assertLess(RN_MOD, RN_SEV)
        self.assertLess(RN_SEV, RN_CRIT)
        self.assertLess(RN_CRIT, RN_MAX)


class TestTrainingDataConsistency(unittest.TestCase):
    """get_training_data() label distribution and boundary invariants."""

    @classmethod
    def setUpClass(cls):
        cls.X, cls.y = get_training_data()
        # Separate synthetic rows (skip the 8 hardcoded real events at the front)
        cls.X_syn = cls.X[8:]
        cls.y_syn = cls.y[8:]

    def test_feature_count_is_11(self):
        """Model expects 11 features; any mismatch breaks inference."""
        self.assertEqual(self.X.shape[1], 11)

    def test_total_sample_count(self):
        """8 real events + 1000 synthetic = 1008 total."""
        self.assertEqual(len(self.X), 1008)

    # ── Label distribution ──────────────────────────────────────────────────
    def test_label_distribution_roughly_equal(self):
        """
        Synthetic data is generated as 4 equal 25% buckets.
        Allow ±10 percentage points tolerance.
        """
        for label in (0, 1, 2, 3):
            proportion = np.mean(self.y_syn == label)
            self.assertGreater(proportion, 0.15, msg=f"Label {label} under-represented: {proportion:.2%}")
            self.assertLess(proportion,    0.35, msg=f"Label {label} over-represented:  {proportion:.2%}")

    def test_all_four_classes_present_in_real_events(self):
        y_real = self.y[:8]
        for label in (0, 1, 2, 3):
            self.assertIn(label, y_real, msg=f"Real events missing class {label}")

    # ── Boundary invariants ─────────────────────────────────────────────────
    def test_no_critical_row_has_peak_below_crit_threshold(self):
        """
        Every synthetic CRITICAL row must have peak_level >= PK_CRIT.
        (column 0 is peak_level_m)
        """
        critical_peaks = self.X_syn[self.y_syn == 3, 0]
        self.assertTrue(
            np.all(critical_peaks >= PK_CRIT),
            msg=f"CRITICAL rows with peak < PK_CRIT ({PK_CRIT}): {critical_peaks[critical_peaks < PK_CRIT]}",
        )

    def test_no_low_row_has_peak_above_mod_threshold(self):
        """
        Every synthetic LOW row must have peak_level < PK_MOD.
        """
        low_peaks = self.X_syn[self.y_syn == 0, 0]
        self.assertTrue(
            np.all(low_peaks < PK_MOD),
            msg=f"LOW rows with peak >= PK_MOD ({PK_MOD}): {low_peaks[low_peaks >= PK_MOD]}",
        )

    def test_no_critical_rain_below_rn_crit(self):
        """
        Sum of T1d..T7d (columns 4-10) for CRITICAL rows must be >= RN_CRIT.
        """
        critical_mask = self.y_syn == 3
        rain_totals = self.X_syn[critical_mask, 4:11].sum(axis=1)
        self.assertTrue(
            np.all(rain_totals >= RN_CRIT),
            msg=f"CRITICAL rows with total rain < RN_CRIT ({RN_CRIT}): {rain_totals[rain_totals < RN_CRIT]}",
        )

    def test_no_low_rain_above_rn_mod(self):
        """
        Sum of T1d..T7d for LOW rows must be < RN_MOD.
        """
        low_mask = self.y_syn == 0
        rain_totals = self.X_syn[low_mask, 4:11].sum(axis=1)
        self.assertTrue(
            np.all(rain_totals < RN_MOD),
            msg=f"LOW rows with total rain >= RN_MOD ({RN_MOD}): {rain_totals[rain_totals >= RN_MOD]}",
        )

    def test_peak_values_non_negative(self):
        self.assertTrue(np.all(self.X[:, 0] >= 0))

    def test_rain_values_non_negative(self):
        self.assertTrue(np.all(self.X[:, 4:11] >= 0))

    def test_duration_values_non_negative(self):
        """Column 1 is duration in days — must be >= 0."""
        self.assertTrue(np.all(self.X[:, 1] >= 0))


if __name__ == "__main__":
    unittest.main()
