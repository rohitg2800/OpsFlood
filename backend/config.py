"""
backend/config.py
-----------------
Single source of truth for all environment-variable configuration.

NEVER put secret values in this file.
All secrets must be set as environment variables in Render
(Dashboard -> Service -> Environment -> Add Environment Variable).
"""
import os

# ── data.gov.in Open Government Data Platform ─────────────────────────────────
# Register free at https://data.gov.in to obtain your key.
# Add it to Render: key=DATA_GOV_API_KEY  value=<your key>
DATA_GOV_API_KEY: str = os.environ.get("DATA_GOV_API_KEY", "")
DATA_GOV_BASE_URL: str = "https://api.data.gov.in/resource"
# CWC daily reservoir dataset resource ID (OGD Platform India)
# Source: https://www.data.gov.in/resource/daily-data-reservoir-level-central-water-commission-cwc
DATA_GOV_CWC_RESOURCE_ID: str = "9ef84268-d588-465a-a308-a864a43d0070"

# ── CWC Flood Forecast System ──────────────────────────────────────────────────
# Public government portal - no API key required.
# The backend scrapes the HTML report and normalises it to JSON.
CWC_FFS_BASE_URL: str = "https://ffs.india-water.gov.in"
CWC_FFS_REPORT_PATH: str = "/flood_situation_report.php"

# ── Cache TTLs ────────────────────────────────────────────────────────────────
FFS_CACHE_SECONDS: int    = 15 * 60       # CWC FFS: refresh every 15 minutes
RESERVOIR_CACHE_SECONDS: int = 60 * 60   # data.gov.in: refresh every hour

# ── OpsFlood general ──────────────────────────────────────────────────────────
PORT: int          = int(os.environ.get("PORT", "8000"))
DEBUG: bool        = os.environ.get("DEBUG", "false").lower() == "true"
DATABASE_URL: str  = os.environ.get("DATABASE_URL", "")
