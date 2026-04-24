import unittest

from backend.app import health


class BackendHealthTests(unittest.TestCase):
    def test_health_payload_exposes_ci_relevant_sections(self):
        payload = health()

        self.assertEqual(payload["status"], "ok")
        self.assertIn("database", payload)
        self.assertIn("ingestion", payload)
        self.assertIn("artifact_count", payload)
        self.assertIn("version", payload)


if __name__ == "__main__":
    unittest.main()
