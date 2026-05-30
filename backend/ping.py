# keep-alive ping endpoint — imported and registered in app.py
import datetime
from fastapi import APIRouter

router = APIRouter()

@router.get("/ping", tags=["system"])
def ping():
    """Lightweight keep-alive endpoint.
    Called by the Flutter app every 10 min to prevent Render cold-starts.
    Returns in < 5 ms with zero DB or ML work.
    """
    return {
        "status": "ok",
        "ts": datetime.datetime.utcnow().isoformat() + "Z",
    }
