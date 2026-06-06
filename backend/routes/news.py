# backend/routes/news.py
# Flask Blueprint: GET /api/news
from __future__ import annotations

from flask import Blueprint, jsonify, request

from ..scrapers.news_feed import get_news_json

news_bp = Blueprint('news', __name__)


@news_bp.get('/api/news')
def news_feed():
    """
    Returns Bihar flood news + alerts from NDMA, IMD, WRD Bihar, CWC.
    Query params:
      state — currently only 'bihar' supported (default: 'bihar')
    """
    state = request.args.get('state', 'bihar').lower()
    items = get_news_json(state=state)
    return jsonify(items)
