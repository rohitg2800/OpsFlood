"""
fcm.py — Firebase Cloud Messaging endpoints for Equinox Android app.

Endpoints:
  POST /api/register-device   — store/refresh FCM device token
  POST /api/push-alert        — send a test or manual push (internal use)
  GET  /api/devices           — list registered device count (health check)
"""

import os
import json
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List

import requests
from fastapi import APIRouter
from pydantic import BaseModel

logger = logging.getLogger("opsflood.fcm")

router = APIRouter(prefix="/api", tags=["fcm"])

# ────────────────────────────────────────────────────────────────────────────
# In-memory token store (survives one Render free-tier lifecycle).
# Replace with PostgreSQL-backed table for production persistence.
# Schema: { token: str, platform: str, app: str, registered_at: str }
# ────────────────────────────────────────────────────────────────────────────
_device_registry: Dict[str, Dict[str, Any]] = {}


class DeviceRegistration(BaseModel):
    token:    str
    platform: str = "android"
    app:      str = "equinox_android_v2"


class PushAlertPayload(BaseModel):
    city:          str
    state:         str = ""
    severity:      str = "HIGH"      # CRITICAL | HIGH | MODERATE
    river:         str = ""
    current_level: float = 0.0
    danger_level:  float = 0.0
    message:       str = ""
    tokens:        List[str] = []   # empty → broadcast to all registered


def _get_firebase_server_key() -> str:
    """Read Firebase Server Key from env (set on Render)."""
    return (os.getenv("FIREBASE_SERVER_KEY") or "").strip()


def _send_fcm_v1(token: str, payload: Dict[str, Any]) -> Dict[str, Any]:
    """
    Send a single FCM message using the FCM HTTP v1 API.
    Falls back to legacy FCM API if SERVER_KEY is a legacy key.

    For FCM v1 you need a service-account OAuth2 token.
    For simplicity we use the legacy FCM endpoint which still works
    with a Server Key until Google deprecates it.
    """
    server_key = _get_firebase_server_key()
    if not server_key:
        return {"status": "skipped", "reason": "FIREBASE_SERVER_KEY not configured"}

    headers = {
        "Authorization": f"key={server_key}",
        "Content-Type":  "application/json",
    }
    body = {
        "to": token,
        "priority": "high",
        "notification": {
            "title": f"🚨 {payload.get('city', 'Alert')} — {payload.get('severity', 'HIGH')}",
            "body":  payload.get("message") or
                     f"{payload.get('river', 'River')} at {payload.get('current_level', 0):.1f}m "
                     f"(danger: {payload.get('danger_level', 0):.1f}m)",
            "sound": "default",
        },
        "data": {
            "city":          payload.get("city", ""),
            "state":         payload.get("state", ""),
            "severity":      payload.get("severity", "HIGH"),
            "river":         payload.get("river", ""),
            "current_level": str(payload.get("current_level", 0.0)),
            "danger_level":  str(payload.get("danger_level", 0.0)),
            "message":       payload.get("message", ""),
        },
    }

    try:
        resp = requests.post(
            "https://fcm.googleapis.com/fcm/send",
            headers=headers,
            json=body,
            timeout=10,
        )
        return {"status": "sent", "http_status": resp.status_code, "response": resp.json()}
    except Exception as exc:
        logger.error("[FCM] send failed: %s", exc)
        return {"status": "error", "reason": str(exc)}


# ────────────────────────────────────────────────────────────────────────────
# Public helper — called from CWC threshold monitoring hooks.
# ────────────────────────────────────────────────────────────────────────────
def broadcast_flood_alert(
    city: str,
    state: str,
    severity: str,
    river: str,
    current_level: float,
    danger_level: float,
    message: str = "",
    tokens: List[str] | None = None,
) -> Dict[str, Any]:
    """
    Send a flood alert push to a list of FCM tokens (or all registered devices).
    Called automatically when CWC data crosses CRITICAL/HIGH thresholds.

    Args:
        tokens: specific list to target; if None, all registered tokens are used.

    Returns:
        summary dict with sent/skipped/error counts.
    """
    targets = tokens if tokens else list(_device_registry.keys())
    if not targets:
        return {"status": "no_devices", "sent": 0, "total": 0}

    payload = {
        "city":          city,
        "state":         state,
        "severity":      severity,
        "river":         river,
        "current_level": current_level,
        "danger_level":  danger_level,
        "message":       message or f"{city} flood level {current_level:.1f}m — {severity} alert",
    }

    results = [_send_fcm_v1(token, payload) for token in targets]
    sent    = sum(1 for r in results if r.get("status") == "sent")
    errors  = sum(1 for r in results if r.get("status") == "error")
    skipped = sum(1 for r in results if r.get("status") == "skipped")

    logger.info(
        "[FCM] broadcast city=%s severity=%s sent=%d error=%d skip=%d",
        city, severity, sent, errors, skipped,
    )
    return {"status": "dispatched", "sent": sent, "error": errors, "skipped": skipped, "total": len(targets)}


# ────────────────────────────────────────────────────────────────────────────
# API Routes
# ────────────────────────────────────────────────────────────────────────────

@router.post("/register-device")
async def register_device(payload: DeviceRegistration):
    """
    Called by FcmService._registerTokenWithBackend() in the Flutter app.
    Stores the device FCM token so the backend can push critical alerts.
    """
    token = payload.token.strip()
    if not token:
        return {"status": "error", "message": "Empty token"}

    _device_registry[token] = {
        "token":         token,
        "platform":      payload.platform,
        "app":           payload.app,
        "registered_at": datetime.now(timezone.utc).isoformat(),
    }
    logger.info("[FCM] device registered platform=%s total=%d", payload.platform, len(_device_registry))
    return {
        "status":           "registered",
        "platform":         payload.platform,
        "registered_count": len(_device_registry),
    }


@router.post("/push-alert")
async def push_alert(payload: PushAlertPayload):
    """
    Internal endpoint to manually trigger a push alert — useful for testing
    and for future automated CWC threshold hooks.
    Requires FIREBASE_SERVER_KEY env var set on Render.
    """
    result = broadcast_flood_alert(
        city=payload.city,
        state=payload.state,
        severity=payload.severity,
        river=payload.river,
        current_level=payload.current_level,
        danger_level=payload.danger_level,
        message=payload.message,
        tokens=payload.tokens or None,
    )
    return result


@router.get("/devices")
async def list_devices():
    """Returns count of registered devices. Does NOT expose tokens."""
    return {
        "status":           "ok",
        "registered_count": len(_device_registry),
        "firebase_key_set": bool(_get_firebase_server_key()),
        "note":             "Token store is in-memory. Upgrade to DB for persistence across restarts.",
    }
