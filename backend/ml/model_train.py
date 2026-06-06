# backend/ml/model_train.py
# =============================================================================
# OpsFlood — LSTM Flood Level Prediction — Training Pipeline
# =============================================================================
#
# ARCHITECTURE
#   Input  : sequence of 12 time-steps × 8 features (3-hourly readings)
#            features: gauge_level, rainfall_1h, rainfall_3d, rainfall_7d,
#                      upstream_level, imd_forecast_mm, day_of_year, hour_of_day
#   Output : next 72 hourly gauge levels  (multi-step direct forecast)
#   Model  : Stacked LSTM (64 → 64) + Dense(128) + Dense(72)
#
# DATA SOURCES
#   CWC historical gauge CSV  — https://www.india-water.gov.in  (download manually)
#   IMD GridPoint Rainfall    — https://imdpune.gov.in/lrfindex.php
#   Bihar WRD bulletin CSVs   — https://www.fmiscwrdbihar.gov.in
#
# USAGE
#   1. Place raw CSVs in  data/raw/
#      • cwc_gauges.csv      — columns: date, station, level_m
#      • imd_rainfall.csv   — columns: date, station, rain_1h, rain_3d, rain_7d
#      • imd_forecast.csv   — columns: date, station, forecast_mm
#
#   2. Train:
#      python -m backend.ml.model_train --station Gandhighat
#      python -m backend.ml.model_train --station all      # trains all stations
#
#   3. Output: backend/ml/saved_models/<station>.keras
#              backend/ml/saved_models/bihar_generic.keras  (trained on all stations)
#
# REQUIREMENTS
#   pip install tensorflow>=2.15 pandas numpy scikit-learn matplotlib tqdm joblib
# =============================================================================
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Optional

import joblib
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import MinMaxScaler
from tqdm import tqdm

# ── Paths ────────────────────────────────────────────────────────────────────
ROOT_DIR    = Path(__file__).parents[2]          # project root
DATA_DIR    = ROOT_DIR / 'data'
RAW_DIR     = DATA_DIR / 'raw'
PROC_DIR    = DATA_DIR / 'processed'
MODEL_DIR   = Path(__file__).parent / 'saved_models'
SCALER_DIR  = Path(__file__).parent / 'scalers'

for d in [RAW_DIR, PROC_DIR, MODEL_DIR, SCALER_DIR]:
    d.mkdir(parents=True, exist_ok=True)

# ── Hyper-parameters ───────────────────────────────────────────────────────────
SEQ_LEN     = 12    # 12 × 3h = 36-hour look-back window
FORECAST_H  = 72    # predict next 72 hours
FEATURES    = [
    'level_m',
    'rain_1h',
    'rain_3d',
    'rain_7d',
    'upstream_level',
    'forecast_mm',
    'day_sin',      # sin/cos encoding of day_of_year (seasonality)
    'day_cos',
]
N_FEATURES  = len(FEATURES)

BATCH_SIZE  = 64
EPOCHS      = 80
PATIENCE    = 12          # early-stopping patience
LR          = 1e-3
LSTM_UNITS  = 64
DROPOUT     = 0.20

# All Bihar CWC gauge stations
ALL_STATIONS = [
    'Gandhighat', 'Dighaghat', 'Hathidah', 'Munger', 'Kahalgaon',
    'Bhagalpur', 'Buxar', 'Birpur (CWC)', 'Baltara', 'Basua', 'Kursela',
    'Chatia', 'Dumariaghat', 'Rewaghat', 'Hajipur', 'Dheng Bridge',
    'Benibad', 'Hayaghat', 'Sikandarpur', 'Samastipur', 'Rosera',
    'Khagaria', 'Darauli', 'Gangpur Siswan', 'Dhengraghat', 'Taibpur',
    'Jainagar', 'Jhanjharpur', 'Sonbarsa', 'Kamtaul', 'Sripalpur',
]


# =============================================================================
# 1. DATA LOADING
# =============================================================================

def load_raw_data(station: Optional[str] = None) -> pd.DataFrame:
    """
    Load and merge CWC gauge + IMD rainfall + IMD forecast CSVs.

    Expected CSV schemas
    --------------------
    cwc_gauges.csv   : date (ISO8601), station (str), level_m (float)
    imd_rainfall.csv : date (ISO8601), station (str), rain_1h, rain_3d, rain_7d (float)
    imd_forecast.csv : date (ISO8601), station (str), forecast_mm (float)

    If the real CSVs are missing, synthetic data is generated for development.
    """
    gauge_path    = RAW_DIR / 'cwc_gauges.csv'
    rainfall_path = RAW_DIR / 'imd_rainfall.csv'
    forecast_path = RAW_DIR / 'imd_forecast.csv'

    if not gauge_path.exists():
        print('  ⚠️  cwc_gauges.csv not found — generating synthetic data for demo training.')
        return _generate_synthetic_data(station)

    gauge    = pd.read_csv(gauge_path,    parse_dates=['date'])
    rainfall = pd.read_csv(rainfall_path, parse_dates=['date'])
    forecast = pd.read_csv(forecast_path, parse_dates=['date'])

    df = gauge.merge(rainfall, on=['date', 'station'], how='left')
    df = df.merge(forecast,   on=['date', 'station'], how='left')
    df = df.fillna(method='ffill').fillna(0)

    if station and station != 'all':
        df = df[df['station'] == station].copy()
        if df.empty:
            print(f'  ⚠️  No data found for station "{station}". Using synthetic data.')
            return _generate_synthetic_data(station)

    df = df.sort_values(['station', 'date']).reset_index(drop=True)
    return df


def _generate_synthetic_data(station: Optional[str]) -> pd.DataFrame:
    """
    Generates ~4 years of 3-hourly synthetic data for one or all stations.
    Uses a realistic seasonal monsoon pattern + random noise.
    Only used when real CWC CSVs are unavailable.
    """
    rng    = np.random.default_rng(42)
    dates  = pd.date_range('2020-01-01', '2024-10-31', freq='3h')
    n      = len(dates)
    stations = [station] if (station and station != 'all') else ALL_STATIONS[:5]

    rows = []
    for stn in stations:
        # Base level varies by station (use Gandhighat-like range ~44–50m)
        base     = rng.uniform(44.0, 46.0)
        for i, d in enumerate(dates):
            doy      = d.timetuple().tm_yday
            # Monsoon peak Jun–Sep  (doy 152–273)
            monsoon  = 3.0 * max(0, np.sin(np.pi * (doy - 100) / 200))
            noise    = rng.normal(0, 0.15)
            level    = base + monsoon + noise
            rain_1h  = max(0, rng.exponential(2)  * (1 + monsoon / 3))
            rain_3d  = max(0, rng.exponential(15) * (1 + monsoon / 3))
            rain_7d  = max(0, rng.exponential(40) * (1 + monsoon / 3))
            fcst_mm  = max(0, rain_1h * rng.uniform(0.8, 1.2))
            rows.append(dict(
                date=d, station=stn, level_m=round(level, 3),
                rain_1h=round(rain_1h, 2), rain_3d=round(rain_3d, 2),
                rain_7d=round(rain_7d, 2), upstream_level=round(level - 0.3, 3),
                forecast_mm=round(fcst_mm, 2),
            ))
    df = pd.DataFrame(rows)
    print(f'  ✅  Synthetic data: {len(df):,} rows for station(s): {stations}')
    return df


# =============================================================================
# 2. FEATURE ENGINEERING
# =============================================================================

def engineer_features(df: pd.DataFrame) -> pd.DataFrame:
    """Add cyclical time encodings and upstream fallback."""
    df = df.copy()
    # Cyclical day-of-year encoding (captures monsoon seasonality)
    doy         = df['date'].dt.dayofyear
    df['day_sin'] = np.sin(2 * np.pi * doy / 365)
    df['day_cos'] = np.cos(2 * np.pi * doy / 365)

    # Upstream fallback: if missing, use current level − 0.3m
    if 'upstream_level' not in df.columns:
        df['upstream_level'] = df['level_m'] - 0.3
    df['upstream_level'] = df['upstream_level'].fillna(df['level_m'] - 0.3)

    # Fill remaining NaNs
    for col in ['rain_1h', 'rain_3d', 'rain_7d', 'forecast_mm']:
        if col not in df.columns:
            df[col] = 0.0
        df[col] = df[col].fillna(0.0)

    return df


# =============================================================================
# 3. SEQUENCE BUILDING
# =============================================================================

def build_sequences(
    df: pd.DataFrame,
    scaler_x: MinMaxScaler,
    scaler_y: MinMaxScaler,
    fit_scalers: bool = True,
) -> tuple[np.ndarray, np.ndarray]:
    """
    Build (X, y) arrays for LSTM training.
      X : (N, SEQ_LEN, N_FEATURES)  — normalised input sequences
      y : (N, FORECAST_H)            — normalised future gauge levels
    """
    X_list, y_list = [], []
    # FORECAST_H is in hours but our data is 3-hourly, so target steps = FORECAST_H // 3
    target_steps = FORECAST_H // 3   # = 24 steps × 3h = 72h

    for station, grp in df.groupby('station'):
        grp = grp.sort_values('date').reset_index(drop=True)
        vals_x = grp[FEATURES].values.astype(np.float32)
        vals_y = grp['level_m'].values.astype(np.float32)

        if fit_scalers:
            scaler_x.partial_fit(vals_x)
            scaler_y.partial_fit(vals_y.reshape(-1, 1))

        vals_x_n = scaler_x.transform(vals_x)
        vals_y_n = scaler_y.transform(vals_y.reshape(-1, 1)).flatten()

        total = len(grp) - SEQ_LEN - target_steps
        if total <= 0:
            continue
        for i in range(total):
            X_list.append(vals_x_n[i : i + SEQ_LEN])
            y_list.append(vals_y_n[i + SEQ_LEN : i + SEQ_LEN + target_steps])

    X = np.array(X_list, dtype=np.float32)
    y = np.array(y_list, dtype=np.float32)
    print(f'  ✅  Sequences built: X={X.shape}  y={y.shape}')
    return X, y


# =============================================================================
# 4. MODEL DEFINITION
# =============================================================================

def build_model(output_steps: int) -> 'tf.keras.Model':
    """
    Stacked LSTM with dropout + residual-style skip connection.
    Input  : (batch, SEQ_LEN, N_FEATURES)
    Output : (batch, output_steps)  — next N 3-hourly gauge levels
    """
    import tensorflow as tf
    from tensorflow.keras import layers, Model, Input

    inp   = Input(shape=(SEQ_LEN, N_FEATURES), name='gauge_sequence')

    # Layer 1 LSTM
    x     = layers.LSTM(LSTM_UNITS, return_sequences=True,
                        name='lstm_1')(inp)
    x     = layers.Dropout(DROPOUT, name='drop_1')(x)

    # Layer 2 LSTM
    x     = layers.LSTM(LSTM_UNITS, return_sequences=False,
                        name='lstm_2')(x)
    x     = layers.Dropout(DROPOUT, name='drop_2')(x)

    # Dense head
    x     = layers.Dense(128, activation='relu', name='dense_1')(x)
    x     = layers.Dense(64,  activation='relu', name='dense_2')(x)
    out   = layers.Dense(output_steps, name='forecast')(x)

    model = Model(inputs=inp, outputs=out, name='OpsFlood_LSTM')
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=LR),
        loss='huber',            # robust to outliers (better than MSE for floods)
        metrics=['mae'],
    )
    return model


# =============================================================================
# 5. TRAINING
# =============================================================================

def train(
    station:    str  = 'all',
    save_name:  Optional[str] = None,
    plot:       bool = False,
) -> None:
    import tensorflow as tf

    print(f'\n{"═" * 60}')
    print(f'  OpsFlood LSTM Trainer   |   station = {station}')
    print(f'{"═" * 60}')

    # ── 1. Load data
    print('\n[1/6] Loading data…')
    df = load_raw_data(station)
    df = engineer_features(df)
    print(f'       Rows: {len(df):,}  |  Stations: {df["station"].nunique()}')

    # ── 2. Scalers
    print('[2/6] Fitting scalers…')
    scaler_x = MinMaxScaler(feature_range=(0, 1))
    scaler_y = MinMaxScaler(feature_range=(0, 1))
    X, y = build_sequences(df, scaler_x, scaler_y, fit_scalers=True)

    # Save scalers for inference
    scaler_name = save_name or (station.lower().replace(' ', '_'))
    joblib.dump(scaler_x, SCALER_DIR / f'{scaler_name}_x.pkl')
    joblib.dump(scaler_y, SCALER_DIR / f'{scaler_name}_y.pkl')
    print(f'       Scalers saved → {SCALER_DIR}')

    # ── 3. Train / val split (chronological — no shuffle to prevent leakage)
    print('[3/6] Splitting train/val…')
    X_train, X_val, y_train, y_val = train_test_split(
        X, y, test_size=0.15, shuffle=False)
    print(f'       Train: {X_train.shape[0]:,}  |  Val: {X_val.shape[0]:,}')

    # ── 4. Build model
    print('[4/6] Building model…')
    target_steps = FORECAST_H // 3
    model = build_model(output_steps=target_steps)
    model.summary()

    # ── 5. Train
    print('[5/6] Training…')
    callbacks = [
        tf.keras.callbacks.EarlyStopping(
            monitor='val_loss', patience=PATIENCE,
            restore_best_weights=True, verbose=1),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss', factor=0.5, patience=5,
            min_lr=1e-6, verbose=1),
        tf.keras.callbacks.ModelCheckpoint(
            filepath=str(MODEL_DIR / f'{scaler_name}_best.keras'),
            monitor='val_loss', save_best_only=True, verbose=0),
    ]
    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=EPOCHS,
        batch_size=BATCH_SIZE,
        callbacks=callbacks,
        verbose=1,
    )

    # ── 6. Save final model
    print('[6/6] Saving model…')
    model_path = MODEL_DIR / f'{scaler_name}.keras'
    model.save(str(model_path))
    print(f'  ✅  Model saved → {model_path}')

    # Save a generic copy as fallback
    generic_path = MODEL_DIR / 'bihar_generic.keras'
    model.save(str(generic_path))
    print(f'  ✅  Generic fallback → {generic_path}')

    # ── Metrics summary
    val_mae  = min(history.history['val_mae'])
    val_loss = min(history.history['val_loss'])
    print(f'\n  Best val MAE  : {val_mae:.4f}  (normalised)')
    print(f'  Best val loss : {val_loss:.4f}  (Huber)')

    # Estimate real-world MAE in metres
    level_range = scaler_y.data_range_[0] if hasattr(scaler_y, 'data_range_') else 10.0
    mae_m = val_mae * level_range
    print(f'  Est. real MAE : ±{mae_m:.3f} m  (flood prediction accuracy)')

    # ── Save training metadata
    meta = {
        'station':       station,
        'model_version': 'v2.1-lstm',
        'seq_len':       SEQ_LEN,
        'forecast_h':    FORECAST_H,
        'features':      FEATURES,
        'epochs_run':    len(history.history['loss']),
        'val_mae':       round(float(val_mae),  4),
        'val_loss':      round(float(val_loss), 4),
        'mae_metres':    round(float(mae_m),    4),
    }
    with open(MODEL_DIR / f'{scaler_name}_meta.json', 'w') as f:
        json.dump(meta, f, indent=2)
    print(f'  ✅  Metadata saved → {MODEL_DIR / f"{scaler_name}_meta.json"}')

    if plot:
        _plot_training(history, scaler_name)

    print(f'\n{"═" * 60}')
    print('  Training complete! Drop the .keras file onto your Render')
    print('  instance at:  backend/ml/saved_models/<station>.keras')
    print(f'{"═" * 60}\n')


# =============================================================================
# 6. OPTIONAL: TRAINING PLOT
# =============================================================================

def _plot_training(history, name: str) -> None:
    try:
        import matplotlib.pyplot as plt
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4))
        ax1.plot(history.history['loss'],     label='train loss')
        ax1.plot(history.history['val_loss'], label='val loss')
        ax1.set_title('Huber Loss'); ax1.legend(); ax1.grid(True)
        ax2.plot(history.history['mae'],      label='train MAE')
        ax2.plot(history.history['val_mae'],  label='val MAE')
        ax2.set_title('MAE'); ax2.legend(); ax2.grid(True)
        plt.suptitle(f'OpsFlood LSTM — {name}', fontweight='bold')
        plt.tight_layout()
        plot_path = MODEL_DIR / f'{name}_training.png'
        plt.savefig(str(plot_path), dpi=150)
        print(f'  ✅  Training plot saved → {plot_path}')
        plt.close()
    except ImportError:
        print('  ⚠️  matplotlib not installed — skipping plot')


# =============================================================================
# 7. EVALUATION HELPER
# =============================================================================

def evaluate(station: str = 'Gandhighat') -> None:
    """
    Load a saved model and print prediction vs actual for last 72 hours.
    Run: python -m backend.ml.model_train --eval --station Gandhighat
    """
    import tensorflow as tf

    scaler_name = station.lower().replace(' ', '_')
    model_path  = MODEL_DIR / f'{scaler_name}.keras'
    sx_path     = SCALER_DIR / f'{scaler_name}_x.pkl'
    sy_path     = SCALER_DIR / f'{scaler_name}_y.pkl'

    if not model_path.exists():
        print(f'No model found at {model_path}. Train first.')
        return

    model    = tf.keras.models.load_model(str(model_path))
    scaler_x = joblib.load(sx_path)
    scaler_y = joblib.load(sy_path)

    df   = load_raw_data(station)
    df   = engineer_features(df)
    grp  = df[df['station'] == station].sort_values('date').tail(SEQ_LEN + FORECAST_H // 3 + 10)

    vals_x = grp[FEATURES].values[-SEQ_LEN:].astype(np.float32)
    vals_x_n = scaler_x.transform(vals_x)
    X_eval = vals_x_n[np.newaxis, ...]          # shape (1, SEQ_LEN, N_FEATURES)

    pred_n = model.predict(X_eval, verbose=0)[0]
    pred   = scaler_y.inverse_transform(pred_n.reshape(-1, 1)).flatten()

    print(f'\nPredicted next {FORECAST_H}h for {station} (every 3h):')
    print(f'{"Hour":>6}  {"Level (m)":>12}  {"Status":>10}')
    print('-' * 34)
    from backend.ml.flood_predictor import GAUGE_THRESHOLDS
    thresholds = GAUGE_THRESHOLDS.get(station, {'danger': 50.0, 'warning': 48.0})
    for i, level in enumerate(pred):
        h      = (i + 1) * 3
        status = ('DANGER'  if level >= thresholds['danger']
                  else 'WARNING' if level >= thresholds['warning']
                  else 'SAFE')
        print(f'{h:>5}h   {level:>10.3f} m   {status:>8}')


# =============================================================================
# 8. ENTRY POINT
# =============================================================================

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='OpsFlood LSTM Trainer',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  Train one station:
    python -m backend.ml.model_train --station Gandhighat

  Train generic Bihar model (all stations):
    python -m backend.ml.model_train --station all

  Train with plot output:
    python -m backend.ml.model_train --station Gandhighat --plot

  Evaluate saved model:
    python -m backend.ml.model_train --eval --station Gandhighat
    ''')
    parser.add_argument('--station', default='all',
                        help='Station name or "all" for generic Bihar model')
    parser.add_argument('--plot',    action='store_true',
                        help='Save training loss/MAE plot as PNG')
    parser.add_argument('--eval',    action='store_true',
                        help='Run evaluation on saved model (no training)')
    args = parser.parse_args()

    if args.eval:
        evaluate(station=args.station)
    else:
        train(station=args.station, plot=args.plot)
