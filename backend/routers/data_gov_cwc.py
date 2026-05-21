"""
backend/routers/data_gov_cwc.py
--------------------------------
Proxy for the data.gov.in CWC daily reservoir level dataset.

Dataset: Daily Data of Reservoir Level - Central Water Commission (CWC)
URL:     https://www.data.gov.in/resource/daily-data-reservoir-level-central-water-commission-cwc
ID:      9ef84268-d588-465a-a308-a864a43d0070
Licence: Open Government Data (OGD) Platform India - free public reuse.

API KEY
-------
The data.gov.in API requires a free API key.
NEVER hardcode the key here. Add it to Render environment variables:
  Key:   DATA_GOV_API_KEY
  Value: <your key from data.gov.in>

Endpoints
---------
GET /api/cwc-reservoir              - all reservoirs (cached hourly)
GET /api/cwc-reservoir/state        - ?state=Maharashtra
GET /api/cwc-reservoir/search       - ?name=Koyna  (fuzzy)
"""
import time
import logging
from difflib import get_close_matches
from typing import Optional

import httpx
from fastapi import APIRouter, Query, HTTPException

from backend.config import (
    DATA_GOV_API_KEY,
    DATA_GOV_BASE_URL,
    DATA_GOV_CWC_RESOURCE_ID,
    RESERVOIR_CACHE_SECONDS,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/cwc-reservoir", tags=["CWC Reservoir (data.gov.in)"])

# ── In-memory cache ────────────────────────────────────────────────────────────
_reservoir_cache: list[dict] = []
_reservoir_cache_ts: float   = 0.0
_FETCH_LIMIT = 500   # data.gov.in max records per request


def _normalise_record(rec: dict) -> dict:
    """Flatten / rename data.gov.in field names to consistent snake_case keys."""
    def _f(val) -> float:
        try:   return float(str(val).replace(",", ""))
        except: return 0.0

    frl  = _f(rec.get("full_reservoir_level_m") or rec.get("FRL") or rec.get("frl") or 0)
    curr = _f(rec.get("current_level_m") or rec.get("water_level") or rec.get("wl") or 0)
    cap  = _f(rec.get("total_capacity_mcm") or rec.get("gross_storage") or rec.get("total_capacity") or 0)
    live = _f(rec.get("live_storage_mcm")   or rec.get("live_storage") or 0)
    pct  = round(live / cap * 100, 1) if cap > 0 else 0.0

    return {
        "reservoir_name":       str(rec.get("reservoir_name") or rec.get("name") or rec.get("project_name") or ""),
        "state":                str(rec.get("state") or rec.get("State") or ""),
        "basin":                str(rec.get("basin") or rec.get("river_basin") or ""),
        "full_reservoir_level_m": frl,
        "current_level_m":      curr,
        "live_storage_mcm":     live,
        "total_capacity_mcm":   cap,
        "live_storage_pct":     min(pct, 100.0),
        "data_date":            str(rec.get("date") or rec.get("report_date") or rec.get("data_date") or ""),
    }


async def _fetch_all_reservoirs() -> list[dict]:
    """Fetch all CWC reservoir records from data.gov.in, with hourly cache."""
    global _reservoir_cache, _reservoir_cache_ts

    now = time.time()
    if _reservoir_cache and (now - _reservoir_cache_ts) < RESERVOIR_CACHE_SECONDS:
        return _reservoir_cache

    if not DATA_GOV_API_KEY:
        logger.error(
            "DATA_GOV_API_KEY is not set. "
            "Add it to Render environment variables. "
            "Register free at https://data.gov.in"
        )
        return _reservoir_cache

    url = f"{DATA_GOV_BASE_URL}/{DATA_GOV_CWC_RESOURCE_ID}"
    params = {
        "api-key": DATA_GOV_API_KEY,
        "format":  "json",
        "limit":   _FETCH_LIMIT,
        "offset":  0,
    }

    all_records: list[dict] = []
    try:
        async with httpx.AsyncClient(timeout=20) as client:
            # Paginate until we have all records
            while True:
                resp = await client.get(url, params=params)
                resp.raise_for_status()
                body = resp.json()

                records = body.get("records") or body.get("data") or []
                if not records:
                    break

                all_records.extend([_normalise_record(r) for r in records])

                total = int(body.get("total") or body.get("count") or 0)
                if len(all_records) >= total or len(records) < _FETCH_LIMIT:
                    break

                params["offset"] += _FETCH_LIMIT

    except Exception as exc:
        logger.warning("data.gov.in reservoir fetch failed: %s", exc)
        return _reservoir_cache   # return stale on error

    if all_records:
        _reservoir_cache    = all_records
        _reservoir_cache_ts = now

    return _reservoir_cache


# ── Routes ─────────────────────────────────────────────────────────────────────

@router.get("", summary="All CWC reservoir levels (data.gov.in)")
async def get_all_reservoirs(
    min_pct: Optional[float] = Query(None, description="Filter: minimum fill % e.g. 85"),
    limit:   int             = Query(200,  description="Max records to return"),
    sort:    str             = Query("",   description="'pct_desc' or 'pct_asc'"),
):
    records = await _fetch_all_reservoirs()

    if min_pct is not None:
        records = [r for r in records if r["live_storage_pct"] >= min_pct]

    if sort == "pct_desc":
        records = sorted(records, key=lambda r: r["live_storage_pct"], reverse=True)
    elif sort == "pct_asc":
        records = sorted(records, key=lambda r: r["live_storage_pct"])

    records = records[:limit]
    return {"status": "success", "count": len(records), "data": records}


@router.get("/state", summary="CWC reservoir levels for a state")
async def get_reservoirs_by_state(
    state:   str             = Query(..., description="State name e.g. Maharashtra"),
    min_pct: Optional[float] = Query(None),
):
    records = await _fetch_all_reservoirs()
    filtered = [r for r in records if state.lower() in r["state"].lower()]
    if min_pct is not None:
        filtered = [r for r in filtered if r["live_storage_pct"] >= min_pct]
    return {"status": "success", "state": state, "count": len(filtered), "data": filtered}


@router.get("/search", summary="Search reservoirs by name (fuzzy)")
async def search_reservoirs(
    name: str = Query(..., description="Reservoir or project name e.g. Koyna"),
):
    records  = await _fetch_all_reservoirs()
    names    = [r["reservoir_name"] for r in records]
    matches  = get_close_matches(name, names, n=5, cutoff=0.4)

    if not matches:
        # Substring fallback
        result = [r for r in records if name.lower() in r["reservoir_name"].lower()]
    else:
        result = [r for r in records if r["reservoir_name"] in matches]

    return {"status": "success", "query": name, "count": len(result), "data": result}
