# backend/routes/predict.py
# Flask Blueprint: GET /api/predict/<station>
# GET /api/predict/<station>?level=48.2&r3d=120&r7d=300
from __future__ import annotations

from flask import Blueprint, jsonify, request

from ..ml.flood_predictor import FloodPredictor, GAUGE_THRESHOLDS

predict_bp = Blueprint('predict', __name__)


@predict_bp.get('/api/predict/<station>')
def predict(station: str):
    """
    Returns LSTM flood predictions for the given Bihar gauge station.

    Query params:
      level   — current river level (m MSL)  [required]
      r3d     — last 3-day rainfall mm        [optional, default 60]
      r7d     — last 7-day rainfall mm        [optional, default 150]
      upstream — upstream gauge level         [optional]
      imd     — IMD forecast 24h rain mm      [optional, default 0]
    """
    if station not in GAUGE_THRESHOLDS:
        # fuzzy match
        match = next(
            (k for k in GAUGE_THRESHOLDS if
             station.lower() in k.lower() or k.lower() in station.lower()),
            None)
        if match is None:
            return jsonify({'error': f'Unknown station: {station}',
                            'valid_stations': list(GAUGE_THRESHOLDS.keys())}), 404
        station = match

    try:
        current_level  = float(request.args.get('level',  47.0))
        rainfall_3d    = float(request.args.get('r3d',    60.0))
        rainfall_7d    = float(request.args.get('r7d',   150.0))
        upstream       = request.args.get('upstream')
        upstream_level = float(upstream) if upstream else None
        imd_forecast   = float(request.args.get('imd',    0.0))
    except (ValueError, TypeError) as exc:
        return jsonify({'error': str(exc)}), 400

    predictor = FloodPredictor(station)
    result    = predictor.predict(
        current_level, rainfall_3d, rainfall_7d,
        upstream_level, imd_forecast)
    return jsonify(result)


@predict_bp.get('/api/predict')
def list_stations():
    """Returns all supported Bihar gauge stations."""
    return jsonify({
        'stations': list(GAUGE_THRESHOLDS.keys()),
        'total':    len(GAUGE_THRESHOLDS),
        'state':    'Bihar',
    })
