"""
RainCheck ML Microservice — Flask API
Serves premium pricing, risk assessment, fraud detection, and disruption prediction.
"""
import sys
import io
import json
import warnings
from pathlib import Path
from datetime import datetime, timedelta

# Force UTF-8 output so Windows cp1252 terminals don't crash on unicode chars
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

warnings.filterwarnings('ignore')

from flask import Flask, jsonify, request
from flask_cors import CORS
from dotenv import load_dotenv
import os
import numpy as np
import pandas as pd

load_dotenv()
app  = Flask(__name__)
CORS(app)

PORT      = int(os.getenv('PORT', 8000))
ROOT      = Path(__file__).parent
MODEL_DIR = ROOT / 'models'

# ── City config (mirrors server/src/config/cities.ts) ────────────────────────
CITY_BASE_RISK = {
    'Delhi': 80, 'Mumbai': 65, 'Chennai': 58, 'Kolkata': 62,
    'Jaipur': 65, 'Lucknow': 60, 'Hyderabad': 50, 'Pune': 44,
    'Ahmedabad': 48, 'Bangalore': 30,
}
CITY_PREMIUM_MULT = {
    'Delhi': 1.45, 'Mumbai': 1.35, 'Kolkata': 1.25, 'Chennai': 1.20,
    'Jaipur': 1.15, 'Lucknow': 1.15, 'Hyderabad': 1.10, 'Pune': 1.05,
    'Ahmedabad': 1.00, 'Bangalore': 0.90,
}
CITY_TOP_RISKS = {
    'Delhi':     ['SevereAQI', 'ExtremeHeat'],
    'Mumbai':    ['Flooding', 'HeavyRain'],
    'Chennai':   ['Flooding', 'HeavyRain'],
    'Kolkata':   ['HeavyRain', 'Flooding'],
    'Hyderabad': ['Flooding', 'HeavyRain'],
    'Pune':      ['HeavyRain', 'Flooding'],
    'Jaipur':    ['ExtremeHeat', 'HeavyRain'],
    'Lucknow':   ['ExtremeHeat', 'SevereAQI'],
    'Ahmedabad': ['ExtremeHeat', 'SevereAQI'],
    'Bangalore': ['HeavyRain', 'SocialDisruption'],
}

# ── Model registry ────────────────────────────────────────────────────────────
_models: dict = {}
models_loaded = False

def load_models():
    global _models, models_loaded
    try:
        import joblib
        # Auto-train on first run if model files are missing
        if not (MODEL_DIR / 'premium_model.pkl').exists():
            print('[INFO] Model files not found — training now (this takes ~30s)...')
            import subprocess, os
            env = {**os.environ, 'PYTHONIOENCODING': 'utf-8'}
            subprocess.run(
                [sys.executable, str(ROOT / 'scripts' / 'train_models.py')],
                check=True, env=env
            )
        _models['premium']    = joblib.load(MODEL_DIR / 'premium_model.pkl')
        _models['risk']       = joblib.load(MODEL_DIR / 'risk_model.pkl')
        _models['fraud']      = joblib.load(MODEL_DIR / 'fraud_model.pkl')
        _models['disruption'] = joblib.load(MODEL_DIR / 'disruption_model.pkl')
        models_loaded = True
        print('[OK] All ML models loaded')
    except Exception as e:
        print(f'[WARN] Models not loaded: {e}')
        models_loaded = False

load_models()

# ── Helpers ───────────────────────────────────────────────────────────────────

def err(msg: str, code: int = 400):
    return jsonify({'success': False, 'error': msg}), code

def ok(data: dict, message: str = ''):
    resp = {'success': True, 'data': data}
    if message:
        resp['message'] = message
    return jsonify(resp)

def get_season() -> str:
    m = datetime.utcnow().month
    if m in [6, 7, 8, 9]:  return 'monsoon'
    if m in [11, 12, 1, 2]: return 'winter'
    return 'summer'

def score_to_tier(score: float) -> str:
    if score >= 75: return 'VeryHigh'
    if score >= 55: return 'High'
    if score >= 35: return 'Medium'
    return 'Low'

# ── Heuristic fallbacks (used when models are not loaded) ─────────────────────

def heuristic_risk_score(city, vehicle_type, experience_months,
                          avg_daily_hours, aqi=100, rainfall=0, temperature=28) -> float:
    base     = CITY_BASE_RISK.get(city, 50)
    v_adj    = {'Bicycle': 8, 'Scooter': 2, 'Motorcycle': 0}.get(vehicle_type, 0)
    h_adj    = max(0, (avg_daily_hours - 8) / 6) * 5
    e_adj    = min(experience_months / 60, 1) * 12
    w_adj    = (max(0, aqi - 50) / 450) * 15 + (rainfall / 600) * 10 + (max(0, temperature - 30) / 20) * 8
    return float(np.clip(base + v_adj + h_adj - e_adj + w_adj, 0, 100))

def heuristic_premium(city, plan_type, experience_months, recent_claims,
                       season=None, zone_risk=1.0) -> float:
    base_rates = {'Basic': 35, 'Standard': 55, 'Premium': 75}
    base      = base_rates.get(plan_type, 55)
    city_m    = CITY_PREMIUM_MULT.get(city, 1.0)
    exp_d     = 0.90 if experience_months > 24 else (0.95 if experience_months > 12 else 1.0)
    claims_a  = 1 + min(recent_claims, 4) * 0.05
    season_m  = {'monsoon': 1.15, 'winter': 1.10, 'summer': 1.05}.get(season or get_season(), 1.0)
    risk_load = 1 + (heuristic_risk_score(city, 'Scooter', experience_months, 9) / 100) * 0.40
    return float(np.clip(base * city_m * zone_risk * season_m * exp_d * claims_a * risk_load, 29, 90))


# ═══════════════════════════════════════════════════════════════════════════════
# ENDPOINTS
# ═══════════════════════════════════════════════════════════════════════════════

# ── GET /health ───────────────────────────────────────────────────────────────
@app.route('/health')
def health_legacy():
    return jsonify({'success': True, 'data': {'status': 'ok', 'service': 'raincheck-ml', 'version': '1.0.0'}})

# ── GET /api/ml/health ────────────────────────────────────────────────────────
@app.route('/api/ml/health')
def ml_health():
    meta = {}
    meta_path = MODEL_DIR / 'metadata.json'
    if meta_path.exists():
        with open(meta_path) as f:
            meta = json.load(f)

    return ok({
        'status':        'healthy',
        'models_loaded': models_loaded,
        'version':       '1.0.0',
        'trained_at':    meta.get('trained_at'),
        'model_metrics': {
            name: {k: v for k, v in m.items() if k != 'feature_names'}
            for name, m in meta.get('models', {}).items()
        } if meta else None,
    })


# ── POST /api/ml/calculate-premium ───────────────────────────────────────────
@app.route('/api/ml/calculate-premium', methods=['POST'])
def calculate_premium():
    d = request.get_json(silent=True) or {}
    city             = d.get('city', 'Mumbai')
    plan_type        = d.get('plan_type', 'Standard')
    experience_months= int(d.get('experience_months', 12))
    vehicle_type     = d.get('vehicle_type', 'Scooter')
    avg_weekly_earn  = float(d.get('avg_weekly_earnings', 350000))
    avg_daily_hours  = float(d.get('avg_daily_hours', 9))
    preferred_shift  = d.get('preferred_shift', 'Mixed')
    platform         = d.get('platform', 'Zomato')
    zone_risk        = float(d.get('zone_risk_level', 1.0))
    recent_claims    = int(d.get('historical_claims_count', 0))
    season           = d.get('season', get_season())
    aqi_30d          = float(d.get('aqi_avg_30d', 100))
    rain_30d         = float(d.get('rainfall_avg_30d', 20))
    temp_30d         = float(d.get('temperature_avg_30d', 30))
    hist_disruption  = float(d.get('historical_disruption_freq', 2.0))

    risk_score = heuristic_risk_score(city, vehicle_type, experience_months,
                                      avg_daily_hours, aqi_30d, rain_30d, temp_30d)

    if models_loaded:
        try:
            pipe     = _models['premium']
            row      = pd.DataFrame([{
                'city': city, 'zone_risk_level': zone_risk, 'platform': platform,
                'avg_weekly_earnings': avg_weekly_earn / 100,  # paise → rupees
                'avg_daily_hours': avg_daily_hours, 'preferred_shift': preferred_shift,
                'vehicle_type': vehicle_type, 'experience_months': experience_months,
                'historical_claims_count': recent_claims,
                'historical_disruption_freq': hist_disruption,
                'season': season, 'aqi_avg_30d': aqi_30d,
                'rainfall_avg_30d': rain_30d, 'temperature_avg_30d': temp_30d,
            }])
            ml_premium = float(np.clip(pipe.predict(row)[0], 29, 90))
            source = 'xgboost_model'
        except Exception as e:
            print(f'  Premium model inference error: {e}')
            ml_premium = heuristic_premium(city, plan_type, experience_months, recent_claims, season, zone_risk)
            source = 'heuristic_fallback'
    else:
        ml_premium = heuristic_premium(city, plan_type, experience_months, recent_claims, season, zone_risk)
        source = 'heuristic_fallback'

    # Plan coverage adjustments
    plan_offsets = {'Basic': -15, 'Standard': 0, 'Premium': +15}
    final_premium = round(np.clip(ml_premium + plan_offsets.get(plan_type, 0), 29, 90), 1)

    # Factor breakdown
    city_mult   = CITY_PREMIUM_MULT.get(city, 1.0)
    exp_d       = 0.90 if experience_months > 24 else (0.95 if experience_months > 12 else 1.0)
    season_m    = {'monsoon': 1.15, 'winter': 1.10, 'summer': 1.05}.get(season, 1.0)
    claims_a    = 1 + min(recent_claims, 4) * 0.05

    return ok({
        'weekly_premium_inr':  final_premium,
        'weekly_premium_paise': int(final_premium * 100),
        'risk_score':          round(risk_score, 1),
        'risk_tier':           score_to_tier(risk_score),
        'plan_type':           plan_type,
        'source':              source,
        'breakdown': {
            'base_premium_inr':    35.0,
            'city_multiplier':     city_mult,
            'zone_factor':         round(zone_risk, 3),
            'seasonal_multiplier': season_m,
            'experience_discount': exp_d,
            'claims_loading':      claims_a,
            'plan_offset_inr':     plan_offsets.get(plan_type, 0),
            'final_inr':           final_premium,
        },
    })


# ── POST /api/ml/assess-risk ──────────────────────────────────────────────────
@app.route('/api/ml/assess-risk', methods=['POST'])
def assess_risk():
    d = request.get_json(silent=True) or {}
    city             = d.get('city', 'Mumbai')
    vehicle_type     = d.get('vehicle_type', 'Scooter')
    experience_months= int(d.get('experience_months', 12))
    avg_daily_hours  = float(d.get('avg_daily_hours', 9))
    platform         = d.get('platform', 'Zomato')
    preferred_shift  = d.get('preferred_shift', 'Mixed')
    zone_risk        = float(d.get('zone_risk_level', 1.0))
    recent_claims    = int(d.get('historical_claims_count', 0))
    aqi_30d          = float(d.get('aqi_avg_30d', 100))
    rain_30d         = float(d.get('rainfall_avg_30d', 20))
    temp_30d         = float(d.get('temperature_avg_30d', 30))
    season           = d.get('season', get_season())
    hist_disruption  = float(d.get('historical_disruption_freq', 2.0))

    risk_score = heuristic_risk_score(city, vehicle_type, experience_months,
                                      avg_daily_hours, aqi_30d, rain_30d, temp_30d)

    if models_loaded:
        try:
            packed = _models['risk']
            pipe   = packed['model']
            le     = packed['label_encoder']
            row    = pd.DataFrame([{
                'city': city, 'zone_risk_level': zone_risk, 'platform': platform,
                'avg_weekly_earnings': 3500, 'avg_daily_hours': avg_daily_hours,
                'preferred_shift': preferred_shift, 'vehicle_type': vehicle_type,
                'experience_months': experience_months,
                'historical_claims_count': recent_claims,
                'historical_disruption_freq': hist_disruption,
                'season': season, 'aqi_avg_30d': aqi_30d,
                'rainfall_avg_30d': rain_30d, 'temperature_avg_30d': temp_30d,
                'risk_score': risk_score,
            }])
            pred_idx   = pipe.predict(row)[0]
            risk_tier  = le.classes_[pred_idx]
            proba      = pipe.predict_proba(row)[0]
            tier_probs = {le.classes_[i]: round(float(p), 3) for i, p in enumerate(proba)}
            source     = 'xgboost_model'
        except Exception as e:
            print(f'  Risk model inference error: {e}')
            risk_tier  = score_to_tier(risk_score)
            tier_probs = {}
            source     = 'heuristic_fallback'
    else:
        risk_tier  = score_to_tier(risk_score)
        tier_probs = {}
        source     = 'heuristic_fallback'

    # Build human-readable risk factors
    factors = []
    city_base = CITY_BASE_RISK.get(city, 50)
    factors.append({'factor': f'City base risk ({city})', 'impact': 'High' if city_base > 60 else 'Medium' if city_base > 40 else 'Low', 'score': float(city_base * 0.4)})
    if aqi_30d > 300:
        factors.append({'factor': f'Air quality (AQI {aqi_30d:.0f})', 'impact': 'Critical', 'score': float(min((aqi_30d - 50) / 450 * 15, 15))})
    elif aqi_30d > 150:
        factors.append({'factor': f'Air quality (AQI {aqi_30d:.0f})', 'impact': 'High', 'score': float((aqi_30d - 50) / 450 * 15)})
    if rain_30d > 100:
        factors.append({'factor': f'Rainfall exposure ({rain_30d:.0f}mm avg)', 'impact': 'High', 'score': float(min(rain_30d / 600 * 10, 10))})
    if temp_30d > 38:
        factors.append({'factor': f'Heat exposure ({temp_30d:.1f}°C avg)', 'impact': 'High', 'score': float(max(0, (temp_30d - 30) / 20 * 8))})
    if vehicle_type == 'Bicycle':
        factors.append({'factor': 'Vehicle type (Bicycle — highest weather exposure)', 'impact': 'High', 'score': 8.0})
    if avg_daily_hours > 10:
        factors.append({'factor': f'Long working hours ({avg_daily_hours}hrs/day)', 'impact': 'Medium', 'score': float((avg_daily_hours - 8) / 6 * 5)})
    if experience_months > 24:
        factors.append({'factor': f'Experience bonus ({experience_months} months)', 'impact': 'Low (reduces risk)', 'score': -float(min(experience_months / 60, 1) * 12)})
    if recent_claims > 1:
        factors.append({'factor': f'Claims history ({recent_claims} recent)', 'impact': 'Medium', 'score': float(min(recent_claims * 3, 12))})
    factors.append({'factor': f'Zone risk ({zone_risk:.2f}x)', 'impact': 'High' if zone_risk > 1.1 else 'Low', 'score': float((zone_risk - 1.0) * 20)})

    top_risks = CITY_TOP_RISKS.get(city, ['HeavyRain'])
    recommendations = []
    if risk_tier in ('High', 'VeryHigh'):
        recommendations.append('Upgrade to Premium plan — covers all 5 disruption triggers')
    if aqi_30d > 200:
        recommendations.append('Carry N95 mask while riding — AQI frequently above safe limits')
    if vehicle_type == 'Bicycle':
        recommendations.append('Consider upgrading to Scooter — significantly reduces weather exposure risk')
    if preferred_shift == 'Night':
        recommendations.append('Night riders face higher risk — consider Mixed shift for better coverage')
    if experience_months < 6:
        recommendations.append('New riders qualify for 15% premium discount after 12 months')
    recommendations.append(f'Top disruption risks in {city}: {", ".join(top_risks)}')

    return ok({
        'risk_score':      round(risk_score, 1),
        'risk_tier':       risk_tier,
        'tier_probabilities': tier_probs,
        'risk_factors':    sorted(factors, key=lambda f: abs(f['score']), reverse=True),
        'recommendations': recommendations,
        'city_top_risks':  top_risks,
        'source':          source,
        'assessed_at':     datetime.utcnow().isoformat() + 'Z',
    })


# ── POST /api/ml/detect-fraud ─────────────────────────────────────────────────
@app.route('/api/ml/detect-fraud', methods=['POST'])
def detect_fraud():
    d = request.get_json(silent=True) or {}
    claim_amount         = float(d.get('claim_amount', 0))
    experience_months    = int(d.get('rider_experience_months', 12))
    claims_last_30       = int(d.get('claims_last_30_days', 0))
    claims_last_7        = int(d.get('claims_last_7_days', 0))
    distance_km          = float(d.get('distance_from_zone_km', 0))
    time_since_hrs       = float(d.get('time_since_last_claim_hours', 168))
    weather_match        = int(d.get('trigger_weather_match', 1))
    others_claimed       = int(d.get('other_riders_same_zone_claimed', 1))
    claim_hour           = int(d.get('claim_hour', 14))
    day_of_week          = int(d.get('day_of_week', 1))
    policy_age_days      = int(d.get('policy_age_days', 30))

    features = np.array([[
        claim_amount, experience_months, claims_last_30, claims_last_7,
        distance_km, time_since_hrs, weather_match, others_claimed,
        claim_hour, day_of_week, policy_age_days,
    ]])

    if models_loaded:
        try:
            packed    = _models['fraud']
            model     = packed['model']
            scaler    = packed['scaler']
            threshold = packed['threshold']
            X_s       = scaler.transform(features)
            proba     = float(model.predict_proba(X_s)[0, 1])
            fraud_score   = round(proba * 100, 1)
            is_suspicious = proba >= threshold
            confidence    = round(max(proba, 1 - proba), 3)
            source        = 'xgboost_model'
        except Exception as e:
            print(f'  Fraud model inference error: {e}')
            proba = None
            source = 'rule_engine'
    else:
        proba = None
        source = 'rule_engine'

    if proba is None:
        # Rule-based fallback
        score = 0
        if claims_last_7 >= 3: score += 30
        if distance_km > 10:   score += 25
        if weather_match == 0: score += 20
        if others_claimed == 0:score += 15
        if claim_hour < 6:     score += 10
        if policy_age_days < 7:score += 15
        fraud_score   = float(np.clip(score, 0, 100))
        is_suspicious = fraud_score >= 40
        confidence    = 0.75
        proba         = fraud_score / 100

    # Build human-readable flags
    flags = []
    if claims_last_7 >= 3:
        flags.append(f'high_claim_frequency:{claims_last_7}_in_7_days')
    if claims_last_30 >= 5:
        flags.append(f'elevated_monthly_frequency:{claims_last_30}_in_30_days')
    if distance_km > 10:
        flags.append(f'gps_mismatch:{distance_km:.1f}km_from_registered_zone')
    elif distance_km > 5:
        flags.append(f'gps_distance_elevated:{distance_km:.1f}km')
    if weather_match == 0:
        flags.append('trigger_weather_conditions_not_verified')
    if others_claimed == 0:
        flags.append('no_other_riders_in_zone_affected')
    if claim_hour < 6:
        flags.append(f'unusual_claim_hour:{claim_hour:02d}:00')
    if policy_age_days < 7:
        flags.append(f'very_new_policy:{policy_age_days}_days_old')
    elif policy_age_days < 30:
        flags.append(f'new_policy:{policy_age_days}_days_old')
    if time_since_hrs < 24:
        flags.append(f'rapid_repeat_claim:{time_since_hrs:.0f}hrs_since_last')

    if is_suspicious:
        recommendation = 'flag_for_manual_review' if fraud_score < 70 else 'flag_fraud'
    else:
        recommendation = 'auto_approve'

    return ok({
        'fraud_score':    fraud_score,
        'is_suspicious':  is_suspicious,
        'flags':          flags,
        'confidence':     confidence,
        'recommendation': recommendation,
        'source':         source,
        'thresholds': {
            'auto_approve':  '< 35',
            'manual_review': '35 – 70',
            'flag_fraud':    '> 70',
        },
    })


# ── POST /api/ml/predict-disruptions ─────────────────────────────────────────
@app.route('/api/ml/predict-disruptions', methods=['POST'])
def predict_disruptions():
    d = request.get_json(silent=True) or {}
    city       = d.get('city', 'Mumbai')
    days_ahead = int(d.get('days_ahead', 7))
    days_ahead = min(days_ahead, 30)

    # Season-based base disruption probabilities
    season = get_season()

    SEASON_BASE_PROBS = {
        'Delhi':     {'monsoon': 0.28, 'winter': 0.52, 'summer': 0.40},
        'Mumbai':    {'monsoon': 0.65, 'winter': 0.12, 'summer': 0.18},
        'Bangalore': {'monsoon': 0.25, 'winter': 0.08, 'summer': 0.15},
        'Chennai':   {'monsoon': 0.35, 'winter': 0.45, 'summer': 0.30},
        'Hyderabad': {'monsoon': 0.40, 'winter': 0.15, 'summer': 0.32},
        'Kolkata':   {'monsoon': 0.55, 'winter': 0.20, 'summer': 0.25},
        'Pune':      {'monsoon': 0.45, 'winter': 0.10, 'summer': 0.20},
        'Ahmedabad': {'monsoon': 0.20, 'winter': 0.15, 'summer': 0.48},
        'Jaipur':    {'monsoon': 0.30, 'winter': 0.18, 'summer': 0.52},
        'Lucknow':   {'monsoon': 0.28, 'winter': 0.38, 'summer': 0.42},
    }

    TYPE_SEASON_WEIGHT = {
        'Delhi':  {
            'winter': {'SevereAQI': 0.55, 'SocialDisruption': 0.25, 'ExtremeHeat': 0.05, 'HeavyRain': 0.10, 'Flooding': 0.05},
            'summer': {'ExtremeHeat': 0.50, 'SevereAQI': 0.20, 'SocialDisruption': 0.15, 'HeavyRain': 0.10, 'Flooding': 0.05},
            'monsoon':{'HeavyRain': 0.30, 'Flooding': 0.20, 'SocialDisruption': 0.25, 'SevereAQI': 0.15, 'ExtremeHeat': 0.10},
        },
        'Mumbai': {
            'monsoon': {'HeavyRain': 0.40, 'Flooding': 0.35, 'SocialDisruption': 0.15, 'ExtremeHeat': 0.05, 'SevereAQI': 0.05},
            'winter':  {'SocialDisruption': 0.40, 'SevereAQI': 0.30, 'ExtremeHeat': 0.15, 'HeavyRain': 0.10, 'Flooding': 0.05},
            'summer':  {'ExtremeHeat': 0.30, 'SocialDisruption': 0.30, 'HeavyRain': 0.20, 'SevereAQI': 0.15, 'Flooding': 0.05},
        },
    }
    DEFAULT_WEIGHTS = {'HeavyRain': 0.25, 'ExtremeHeat': 0.20, 'SevereAQI': 0.20, 'Flooding': 0.20, 'SocialDisruption': 0.15}

    base_prob   = SEASON_BASE_PROBS.get(city, {}).get(season, 0.25)
    type_weights = TYPE_SEASON_WEIGHT.get(city, {}).get(season, DEFAULT_WEIGHTS)

    # If disruption model loaded, use probability table
    if models_loaded:
        try:
            packed     = _models['disruption']
            prob_table = packed.get('prob_table', {})
            city_probs = prob_table.get(city, {}).get(season, {})
            if city_probs:
                type_weights = city_probs
        except Exception:
            pass

    predictions = []
    np.random.seed(int(datetime.utcnow().timestamp()) % 10000)

    for i in range(days_ahead):
        date      = (datetime.utcnow() + timedelta(days=i)).strftime('%Y-%m-%d')
        dow       = (datetime.utcnow() + timedelta(days=i)).weekday()

        # Weekends have slightly higher social disruption probability
        day_mult = 1.10 if dow >= 5 else 1.0

        # Daily disruption probability with some variation
        daily_prob = float(np.clip(base_prob * day_mult * np.random.uniform(0.6, 1.4), 0.02, 0.95))

        if daily_prob > 0.15:
            types     = list(type_weights.keys())
            weights   = list(type_weights.values())
            d_type    = np.random.choice(types, p=np.array(weights) / sum(weights))
            severity_p = np.random.random()
            if severity_p > 0.75: severity = 'Extreme'
            elif severity_p > 0.35: severity = 'Severe'
            else: severity = 'Moderate'
        else:
            d_type   = 'None'
            severity = 'None'

        predictions.append({
            'date':              date,
            'disruption_type':   d_type,
            'probability':       round(daily_prob, 3),
            'expected_severity': severity,
            'day_of_week':       ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][dow],
        })

    high_risk_days = [p for p in predictions if p['probability'] > 0.45]

    return ok({
        'city':           city,
        'season':         season,
        'days_ahead':     days_ahead,
        'base_daily_prob': round(base_prob, 3),
        'predictions':    predictions,
        'high_risk_days': high_risk_days,
        'top_risk_types': sorted(type_weights, key=type_weights.get, reverse=True)[:2],
        'generated_at':   datetime.utcnow().isoformat() + 'Z',
    })


# ── Legacy endpoints (backwards-compatible with Express backend) ──────────────

@app.route('/api/predict/risk', methods=['POST'])
def predict_risk_legacy():
    d            = request.get_json(silent=True) or {}
    city         = d.get('city', 'Mumbai')
    rainfall     = float(d.get('rainfall_mm', 0))
    temperature  = float(d.get('temperature_c', 28))
    aqi          = float(d.get('aqi', 100))
    wind_speed   = float(d.get('wind_speed_kmh', 15))

    score   = 0.0
    triggered = False
    reasons   = []

    if rainfall > 64:
        score = max(score, 0.95); triggered = True; reasons.append('extreme_rainfall')
    elif rainfall > 30:
        score = max(score, 0.70); reasons.append('heavy_rainfall')
    if temperature > 45:
        score = max(score, 0.90); triggered = True; reasons.append('extreme_heat')
    if aqi > 400:
        score = max(score, 0.88); triggered = True; reasons.append('severe_aqi')

    return jsonify({'success': True, 'data': {
        'risk_score': round(score, 4),
        'triggered': triggered,
        'reasons': reasons,
        'payout_eligible': triggered,
    }})


@app.route('/api/predict/premium', methods=['POST'])
def predict_premium_legacy():
    d     = request.get_json(silent=True) or {}
    city  = d.get('city', 'mumbai').capitalize()
    mult  = CITY_PREMIUM_MULT.get(city, 1.0)
    paise = int(5000 * mult)
    return jsonify({'success': True, 'data': {
        'premium_paise': paise, 'premium_inr': paise / 100,
        'city': city, 'risk_multiplier': mult,
    }})


# ─────────────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    print(f'🤖 RainCheck ML Service  →  http://localhost:{PORT}')
    print(f'   Models loaded: {models_loaded}')
    app.run(host='0.0.0.0', port=PORT, debug=True)
