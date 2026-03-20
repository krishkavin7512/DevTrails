# -*- coding: utf-8 -*-
"""
RainCheck - Model Training Script
Trains all 4 ML models and saves them with metadata.
Run from ml-service/ directory: python scripts/train_models.py
"""
import sys
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
import json
import warnings
import subprocess
from pathlib import Path
from datetime import datetime

warnings.filterwarnings('ignore')

import numpy as np
import pandas as pd
import joblib

from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder, StandardScaler, LabelEncoder
from sklearn.model_selection import cross_val_score, train_test_split, StratifiedKFold
from sklearn.metrics import (
    r2_score, mean_squared_error,
    accuracy_score, classification_report, f1_score, recall_score,
)
from sklearn.ensemble import RandomForestClassifier
from xgboost import XGBRegressor, XGBClassifier

# ── Paths ─────────────────────────────────────────────────────────────────────
ROOT      = Path(__file__).parent.parent
DATA_DIR  = ROOT / 'data'
MODEL_DIR = ROOT / 'models'
MODEL_DIR.mkdir(exist_ok=True)

np.random.seed(42)


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

def banner(title: str):
    print(f'\n{"═"*60}')
    print(f'  {title}')
    print(f'{"═"*60}')


def check_metric(name: str, value: float, target: float, higher_better: bool = True):
    ok = value >= target if higher_better else value <= target
    status = '✅' if ok else '⚠️ '
    print(f'  {status}  {name}: {value:.4f}  (target: {"≥" if higher_better else "≤"}{target})')
    return ok


# ─────────────────────────────────────────────────────────────────────────────
# 1. PREMIUM PRICING MODEL  — XGBoost Regressor, target R² > 0.90
# ─────────────────────────────────────────────────────────────────────────────

def train_premium_model(df: pd.DataFrame) -> dict:
    banner('1 / 4  ·  Premium Pricing Model (XGBRegressor)')

    CAT_COLS = ['city', 'platform', 'preferred_shift', 'vehicle_type', 'season']
    NUM_COLS = ['zone_risk_level', 'avg_weekly_earnings', 'avg_daily_hours',
                'experience_months', 'historical_claims_count',
                'historical_disruption_freq', 'aqi_avg_30d',
                'rainfall_avg_30d', 'temperature_avg_30d']

    X = df[CAT_COLS + NUM_COLS]
    y = df['weekly_premium'].values

    preprocessor = ColumnTransformer([
        ('cat', OneHotEncoder(handle_unknown='ignore', sparse_output=False), CAT_COLS),
        ('num', StandardScaler(), NUM_COLS),
    ])

    model = Pipeline([
        ('pre', preprocessor),
        ('reg', XGBRegressor(
            n_estimators=300, max_depth=6, learning_rate=0.08,
            min_child_weight=3, subsample=0.85, colsample_bytree=0.85,
            reg_alpha=0.1, reg_lambda=1.0, random_state=42, n_jobs=-1,
        )),
    ])

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.15, random_state=42)
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    r2   = r2_score(y_test, y_pred)
    rmse = np.sqrt(mean_squared_error(y_test, y_pred))

    # 5-fold cross-validation
    cv_r2 = cross_val_score(model, X, y, cv=5, scoring='r2', n_jobs=-1)

    print(f'  Test samples: {len(X_test)}')
    check_metric('R² (test)',     r2,          0.90)
    check_metric('R² (CV mean)', cv_r2.mean(), 0.88)
    print(f'  RMSE: ₹{rmse:.2f}/week')
    print(f'  CV R²: {cv_r2}')

    out = MODEL_DIR / 'premium_model.pkl'
    joblib.dump(model, out)
    print(f'  → Saved: {out}')

    return {
        'r2_test':    round(r2, 4),
        'r2_cv_mean': round(float(cv_r2.mean()), 4),
        'rmse_test':  round(float(rmse), 4),
        'feature_names': CAT_COLS + NUM_COLS,
    }


# ─────────────────────────────────────────────────────────────────────────────
# 2. RISK ASSESSMENT MODEL  — XGBoost Classifier, target Accuracy > 88%
# ─────────────────────────────────────────────────────────────────────────────

def train_risk_model(df: pd.DataFrame) -> dict:
    banner('2 / 4  ·  Risk Assessment Model (XGBClassifier)')

    # Derive risk tier from risk score (same formula as seedData)
    def score_to_tier(s):
        if s >= 75: return 'VeryHigh'
        if s >= 55: return 'High'
        if s >= 35: return 'Medium'
        return 'Low'

    df = df.copy()
    df['risk_tier'] = df['risk_score'].apply(score_to_tier)

    CAT_COLS = ['city', 'platform', 'preferred_shift', 'vehicle_type', 'season']
    NUM_COLS = ['zone_risk_level', 'avg_weekly_earnings', 'avg_daily_hours',
                'experience_months', 'historical_claims_count',
                'historical_disruption_freq', 'aqi_avg_30d',
                'rainfall_avg_30d', 'temperature_avg_30d', 'risk_score']

    X = df[CAT_COLS + NUM_COLS]
    le = LabelEncoder()
    y  = le.fit_transform(df['risk_tier'])

    preprocessor = ColumnTransformer([
        ('cat', OneHotEncoder(handle_unknown='ignore', sparse_output=False), CAT_COLS),
        ('num', StandardScaler(), NUM_COLS),
    ])

    model = Pipeline([
        ('pre', preprocessor),
        ('clf', XGBClassifier(
            n_estimators=250, max_depth=7, learning_rate=0.08,
            min_child_weight=3, subsample=0.85, colsample_bytree=0.85,
            use_label_encoder=False, eval_metric='mlogloss',
            random_state=42, n_jobs=-1,
        )),
    ])

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.15, random_state=42, stratify=y
    )
    model.fit(X_train, y_train)
    y_pred = model.predict(X_test)

    acc = accuracy_score(y_test, y_pred)
    cv_acc = cross_val_score(model, X, y, cv=5, scoring='accuracy', n_jobs=-1)

    print(f'  Test samples: {len(X_test)}')
    print(f'  Classes: {list(le.classes_)}')
    check_metric('Accuracy (test)',     acc,          0.88)
    check_metric('Accuracy (CV mean)', cv_acc.mean(), 0.86)
    print(f'\n{classification_report(y_test, y_pred, target_names=le.classes_)}')

    # Save model + label encoder together
    out = MODEL_DIR / 'risk_model.pkl'
    joblib.dump({'model': model, 'label_encoder': le}, out)
    print(f'  → Saved: {out}')

    return {
        'accuracy_test':    round(acc, 4),
        'accuracy_cv_mean': round(float(cv_acc.mean()), 4),
        'classes':          list(le.classes_),
        'feature_names':    CAT_COLS + NUM_COLS,
    }


# ─────────────────────────────────────────────────────────────────────────────
# 3. FRAUD DETECTION MODEL  — XGBoost Classifier, F1>0.85, Recall>0.90
# ─────────────────────────────────────────────────────────────────────────────

def train_fraud_model(df: pd.DataFrame) -> dict:
    banner('3 / 4  ·  Fraud Detection Model (XGBClassifier)')

    FEATURES = [
        'claim_amount', 'rider_experience_months', 'claims_last_30_days',
        'claims_last_7_days', 'distance_from_zone_km',
        'time_since_last_claim_hours', 'trigger_weather_match',
        'other_riders_same_zone_claimed', 'claim_hour', 'day_of_week',
        'policy_age_days',
    ]

    X = df[FEATURES].values
    y = df['is_fraudulent'].values

    fraud_rate = y.mean()
    spw = (1 - fraud_rate) / fraud_rate  # scale_pos_weight

    scaler = StandardScaler()

    model_inner = XGBClassifier(
        n_estimators=300, max_depth=5, learning_rate=0.08,
        min_child_weight=2, subsample=0.80, colsample_bytree=0.80,
        scale_pos_weight=spw,
        eval_metric='aucpr',
        random_state=42, n_jobs=-1,
    )

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.20, random_state=42, stratify=y
    )

    X_train_s = scaler.fit_transform(X_train)
    X_test_s  = scaler.transform(X_test)

    model_inner.fit(X_train_s, y_train)

    # Lower threshold for higher recall (0.35 instead of 0.50)
    proba   = model_inner.predict_proba(X_test_s)[:, 1]
    THRESHOLD = 0.35
    y_pred  = (proba >= THRESHOLD).astype(int)

    f1     = f1_score(y_test, y_pred)
    recall = recall_score(y_test, y_pred)
    acc    = accuracy_score(y_test, y_pred)

    print(f'  Test samples: {len(X_test)}  |  Fraud rate: {fraud_rate*100:.1f}%')
    print(f'  scale_pos_weight: {spw:.2f}  |  Decision threshold: {THRESHOLD}')
    check_metric('F1-score  (fraud class)', f1,     0.85)
    check_metric('Recall    (fraud class)', recall, 0.90)
    check_metric('Accuracy  (overall)',     acc,    0.90)
    print(f'\n{classification_report(y_test, y_pred, target_names=["Legit","Fraud"])}')

    out = MODEL_DIR / 'fraud_model.pkl'
    joblib.dump({
        'model': model_inner, 'scaler': scaler,
        'threshold': THRESHOLD, 'feature_names': FEATURES,
    }, out)
    print(f'  → Saved: {out}')

    return {
        'f1_fraud':    round(f1, 4),
        'recall_fraud': round(recall, 4),
        'accuracy':    round(acc, 4),
        'threshold':   THRESHOLD,
        'feature_names': FEATURES,
    }


# ─────────────────────────────────────────────────────────────────────────────
# 4. DISRUPTION PREDICTOR  — Random Forest Classifier
# ─────────────────────────────────────────────────────────────────────────────

def train_disruption_model(df: pd.DataFrame) -> dict:
    banner('4 / 4  ·  Disruption Predictor (RandomForest)')

    CAT_COLS = ['city', 'season', 'disruption_type']
    NUM_COLS = ['month', 'day_of_week', 'rainfall_mm', 'temperature_c',
                'aqi', 'wind_speed_ms']

    # Target: severity (Moderate / Severe / Extreme)
    le = LabelEncoder()
    y  = le.fit_transform(df['severity'])

    X = df[CAT_COLS + NUM_COLS]

    preprocessor = ColumnTransformer([
        ('cat', OneHotEncoder(handle_unknown='ignore', sparse_output=False), CAT_COLS),
        ('num', StandardScaler(), NUM_COLS),
    ])

    model = Pipeline([
        ('pre', preprocessor),
        ('clf', RandomForestClassifier(
            n_estimators=200, max_depth=8, min_samples_leaf=3,
            class_weight='balanced', random_state=42, n_jobs=-1,
        )),
    ])

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.20, random_state=42, stratify=y
    )
    model.fit(X_train, y_train)
    y_pred = model.predict(X_test)

    acc    = accuracy_score(y_test, y_pred)
    cv_acc = cross_val_score(model, X, y, cv=5, scoring='accuracy', n_jobs=-1)

    print(f'  Test samples: {len(X_test)}  |  Severity classes: {list(le.classes_)}')
    print(f'  Accuracy (test):    {acc:.4f}')
    print(f'  Accuracy (CV mean): {cv_acc.mean():.4f}')
    print(f'\n{classification_report(y_test, y_pred, target_names=le.classes_)}')

    # Also build a city × disruption_type probability lookup for /predict-disruptions
    prob_table = {}
    for city in df['city'].unique():
        prob_table[city] = {}
        for season in ['monsoon', 'winter', 'summer']:
            sub = df[(df['city'] == city) & (df['season'] == season)]
            if len(sub) == 0:
                continue
            counts = sub['disruption_type'].value_counts(normalize=True)
            prob_table[city][season] = counts.to_dict()

    out = MODEL_DIR / 'disruption_model.pkl'
    joblib.dump({
        'model': model, 'label_encoder': le,
        'prob_table': prob_table,
        'feature_names': CAT_COLS + NUM_COLS,
    }, out)
    print(f'  → Saved: {out}')

    return {
        'accuracy_test':    round(acc, 4),
        'accuracy_cv_mean': round(float(cv_acc.mean()), 4),
        'classes':          list(le.classes_),
        'feature_names':    CAT_COLS + NUM_COLS,
    }


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    # Step 1: Generate data if not present
    premium_csv    = DATA_DIR / 'premium_training_data.csv'
    fraud_csv      = DATA_DIR / 'fraud_training_data.csv'
    disruption_csv = DATA_DIR / 'disruption_history.csv'

    if not all([premium_csv.exists(), fraud_csv.exists(), disruption_csv.exists()]):
        print('📊 Generating training data first...')
        gen_script = ROOT / 'data' / 'generate_training_data.py'
        subprocess.run([sys.executable, str(gen_script)], check=True)

    # Step 2: Load data
    print('\n📂 Loading training data...')
    df_premium    = pd.read_csv(premium_csv)
    df_fraud      = pd.read_csv(fraud_csv)
    df_disruption = pd.read_csv(disruption_csv)
    print(f'  Premium:     {len(df_premium):,} rows')
    print(f'  Fraud:       {len(df_fraud):,} rows')
    print(f'  Disruption:  {len(df_disruption):,} rows')

    # Step 3: Train all models
    metadata = {
        'trained_at':   datetime.utcnow().isoformat() + 'Z',
        'python':       sys.version.split()[0],
        'models':       {},
    }

    try:
        metadata['models']['premium']    = train_premium_model(df_premium)
    except Exception as e:
        print(f'  ❌ Premium model failed: {e}')
        raise

    try:
        metadata['models']['risk']       = train_risk_model(df_premium)
    except Exception as e:
        print(f'  ❌ Risk model failed: {e}')
        raise

    try:
        metadata['models']['fraud']      = train_fraud_model(df_fraud)
    except Exception as e:
        print(f'  ❌ Fraud model failed: {e}')
        raise

    try:
        metadata['models']['disruption'] = train_disruption_model(df_disruption)
    except Exception as e:
        print(f'  ❌ Disruption model failed: {e}')
        raise

    # Step 4: Save metadata
    meta_path = MODEL_DIR / 'metadata.json'
    with open(meta_path, 'w') as f:
        json.dump(metadata, f, indent=2)
    print(f'\n📋 Metadata saved: {meta_path}')

    # Step 5: Summary
    banner('Training Complete — Summary')
    for name, m in metadata['models'].items():
        print(f'\n  {name.upper()}:')
        for k, v in m.items():
            if k != 'feature_names':
                print(f'    {k}: {v}')

    print('\n✅ All models trained and saved successfully.')
    print(f'   Models saved to: {MODEL_DIR}')
