"""
RainCheck — Synthetic Training Data Generator
Generates realistic datasets for premium pricing, fraud detection, and disruption prediction.
Run from ml-service/ directory: python data/generate_training_data.py
"""
import numpy as np
import pandas as pd
from pathlib import Path

np.random.seed(42)

# ── Constants ─────────────────────────────────────────────────────────────────

CITIES        = ['Mumbai', 'Delhi', 'Bangalore', 'Chennai', 'Hyderabad',
                 'Kolkata', 'Pune', 'Ahmedabad', 'Jaipur', 'Lucknow']
CITY_WEIGHTS  = [0.20, 0.18, 0.15, 0.12, 0.10, 0.07, 0.07, 0.05, 0.04, 0.02]

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

PLATFORMS      = ['Zomato', 'Swiggy', 'Both']
SHIFTS         = ['Morning', 'Afternoon', 'Evening', 'Night', 'Mixed']
VEHICLES       = ['Bicycle', 'Scooter', 'Motorcycle']
SEASONS        = ['monsoon', 'winter', 'summer']

# ── City-season AQI, rainfall, temperature distributions ─────────────────────
# Format: (mean, std)
CITY_WEATHER = {
    'Delhi': {
        'winter':  {'aqi': (380, 80),  'rain': (12, 8),   'temp': (15, 5)},
        'summer':  {'aqi': (188, 40),  'rain': (22, 12),  'temp': (42, 4)},
        'monsoon': {'aqi': (95, 20),   'rain': (98, 45),  'temp': (33, 3)},
    },
    'Mumbai': {
        'winter':  {'aqi': (148, 30),  'rain': (8, 5),    'temp': (25, 3)},
        'summer':  {'aqi': (92, 22),   'rain': (12, 8),   'temp': (33, 2)},
        'monsoon': {'aqi': (62, 15),   'rain': (520, 120),'temp': (29, 2)},
    },
    'Bangalore': {
        'winter':  {'aqi': (82, 20),   'rain': (38, 20),  'temp': (22, 3)},
        'summer':  {'aqi': (68, 15),   'rain': (42, 18),  'temp': (28, 2)},
        'monsoon': {'aqi': (55, 12),   'rain': (180, 60), 'temp': (24, 2)},
    },
    'Chennai': {
        'winter':  {'aqi': (118, 28),  'rain': (185, 80), 'temp': (27, 3)},
        'summer':  {'aqi': (105, 25),  'rain': (45, 22),  'temp': (36, 3)},
        'monsoon': {'aqi': (72, 18),   'rain': (88, 38),  'temp': (31, 2)},
    },
    'Hyderabad': {
        'winter':  {'aqi': (142, 32),  'rain': (10, 8),   'temp': (22, 4)},
        'summer':  {'aqi': (118, 28),  'rain': (18, 10),  'temp': (38, 3)},
        'monsoon': {'aqi': (68, 16),   'rain': (125, 55), 'temp': (28, 2)},
    },
    'Kolkata': {
        'winter':  {'aqi': (198, 45),  'rain': (15, 10),  'temp': (18, 4)},
        'summer':  {'aqi': (108, 28),  'rain': (42, 22),  'temp': (34, 3)},
        'monsoon': {'aqi': (75, 18),   'rain': (380, 90), 'temp': (30, 2)},
    },
    'Pune': {
        'winter':  {'aqi': (122, 28),  'rain': (8, 5),    'temp': (20, 3)},
        'summer':  {'aqi': (95, 22),   'rain': (12, 8),   'temp': (32, 3)},
        'monsoon': {'aqi': (58, 14),   'rain': (180, 65), 'temp': (26, 2)},
    },
    'Ahmedabad': {
        'winter':  {'aqi': (155, 35),  'rain': (3, 3),    'temp': (22, 4)},
        'summer':  {'aqi': (178, 42),  'rain': (5, 4),    'temp': (43, 3)},
        'monsoon': {'aqi': (82, 20),   'rain': (95, 42),  'temp': (30, 2)},
    },
    'Jaipur': {
        'winter':  {'aqi': (172, 40),  'rain': (8, 6),    'temp': (16, 5)},
        'summer':  {'aqi': (215, 48),  'rain': (6, 5),    'temp': (42, 4)},
        'monsoon': {'aqi': (88, 22),   'rain': (125, 55), 'temp': (32, 3)},
    },
    'Lucknow': {
        'winter':  {'aqi': (248, 55),  'rain': (15, 10),  'temp': (12, 5)},
        'summer':  {'aqi': (172, 38),  'rain': (14, 10),  'temp': (40, 4)},
        'monsoon': {'aqi': (98, 22),   'rain': (165, 65), 'temp': (31, 3)},
    },
}


def sample_weather(city: str, season: str, n: int) -> tuple:
    """Sample AQI, rainfall, temperature for a city/season."""
    w = CITY_WEATHER[city][season]
    aqi  = np.clip(np.random.normal(w['aqi'][0],  w['aqi'][1],  n), 30, 550).round(1)
    rain = np.clip(np.random.normal(w['rain'][0], w['rain'][1], n), 0, 800).round(1)
    temp = np.clip(np.random.normal(w['temp'][0], w['temp'][1], n), 10, 50).round(1)
    return aqi, rain, temp


# ─────────────────────────────────────────────────────────────────────────────
# 1. PREMIUM TRAINING DATA (10,000 rows)
# ─────────────────────────────────────────────────────────────────────────────

def generate_premium_data(n: int = 10_000) -> pd.DataFrame:
    print(f"Generating {n} premium training rows...")
    rng = np.random.default_rng(42)

    cities   = rng.choice(CITIES, size=n, p=CITY_WEIGHTS)
    seasons  = rng.choice(SEASONS, size=n)
    platform = rng.choice(PLATFORMS, size=n)
    shift    = rng.choice(SHIFTS,    size=n)
    vehicle  = rng.choice(VEHICLES,  size=n, p=[0.10, 0.55, 0.35])

    # Earnings: Normal(3500, 800) clipped to [2000, 6000] rupees/week
    earnings = np.clip(rng.normal(3500, 800, n), 2000, 6000).round(-2)

    # Hours: Normal(9, 2) clipped to [6, 14]
    hours = np.clip(rng.normal(9, 2, n), 6, 14).round(1)

    # Experience: exponential (most riders 3-18 months)
    experience = np.clip(rng.exponential(12, n) + 2, 1, 60).astype(int)

    # Zone risk: 0.8–1.2
    zone_risk = np.clip(rng.normal(1.0, 0.12, n), 0.80, 1.20).round(3)

    # Historical claims: Poisson(0.8) per month
    hist_claims = rng.poisson(0.8, n)

    # Historical disruption frequency (events/month seen in city)
    hist_disruption = np.clip(rng.normal(2.0, 0.8, n), 0, 6).round(2)

    # Weather per city/season
    aqi_list, rain_list, temp_list = [], [], []
    for c, s in zip(cities, seasons):
        a, r, t = sample_weather(c, s, 1)
        aqi_list.append(a[0]);  rain_list.append(r[0]);  temp_list.append(t[0])
    aqi  = np.array(aqi_list)
    rain = np.array(rain_list)
    temp = np.array(temp_list)

    # ── Risk score (ground truth formula) ──────────────────────────────────
    city_base = np.array([CITY_BASE_RISK[c] for c in cities], dtype=float)

    weather_risk = (
        np.clip((aqi - 50) / 450, 0, 1) * 15 +
        np.clip(rain / 600, 0, 1) * 10 +
        np.clip((temp - 30) / 20, 0, 1) * 8
    )
    vehicle_risk  = np.where(vehicle == 'Bicycle', 8, np.where(vehicle == 'Scooter', 2, 0))
    hours_risk    = np.clip((hours - 8) / 6, 0, 1) * 5
    exp_bonus     = np.clip(experience / 60, 0, 1) * 12
    zone_adj      = (zone_risk - 1.0) * 20
    claims_adj    = np.minimum(hist_claims * 3, 12)

    risk_raw   = city_base + weather_risk + vehicle_risk + hours_risk - exp_bonus + zone_adj + claims_adj
    noise_risk = rng.normal(0, 2, n)
    risk_score = np.clip(risk_raw + noise_risk, 0, 100).round(1)

    # ── Weekly premium (rupees) ─────────────────────────────────────────────
    base_premium = 35.0
    city_mult    = np.array([CITY_PREMIUM_MULT[c] for c in cities])
    exp_discount = np.where(experience > 24, 0.90, np.where(experience > 12, 0.95, 1.0))
    claims_adj_p = 1 + np.minimum(hist_claims, 4) * 0.05
    season_mult  = np.where(seasons == 'monsoon', 1.15, np.where(seasons == 'winter', 1.10, 1.05))
    vehicle_mult = np.where(vehicle == 'Bicycle', 1.10, np.where(vehicle == 'Scooter', 1.0, 0.97))
    zone_mult    = zone_risk
    risk_load    = 1 + (risk_score / 100) * 0.60

    premium_raw  = base_premium * city_mult * zone_mult * season_mult * exp_discount * claims_adj_p * vehicle_mult * risk_load
    noise_prem   = rng.normal(0, 1.5, n)
    weekly_premium = np.clip(premium_raw + noise_prem, 29, 90).round(1)

    df = pd.DataFrame({
        'city':                        cities,
        'zone_risk_level':             zone_risk,
        'platform':                    platform,
        'avg_weekly_earnings':         earnings,
        'avg_daily_hours':             hours,
        'preferred_shift':             shift,
        'vehicle_type':                vehicle,
        'experience_months':           experience,
        'historical_claims_count':     hist_claims,
        'historical_disruption_freq':  hist_disruption,
        'season':                      seasons,
        'aqi_avg_30d':                 aqi,
        'rainfall_avg_30d':            rain,
        'temperature_avg_30d':         temp,
        'risk_score':                  risk_score,
        'weekly_premium':              weekly_premium,
    })
    return df


# ─────────────────────────────────────────────────────────────────────────────
# 2. FRAUD TRAINING DATA (5,000 rows, 8% fraud)
# ─────────────────────────────────────────────────────────────────────────────

def generate_fraud_data(n: int = 5_000, fraud_rate: float = 0.08) -> pd.DataFrame:
    print(f"Generating {n} fraud training rows ({fraud_rate*100:.0f}% fraud)...")
    rng = np.random.default_rng(123)

    n_fraud = int(n * fraud_rate)
    n_legit = n - n_fraud

    rows = []

    # ── Legitimate claims ──────────────────────────────────────────────────
    for _ in range(n_legit):
        rows.append({
            'claim_amount':                    rng.integers(40, 180) * 100,
            'rider_experience_months':         int(np.clip(rng.exponential(14) + 3, 1, 60)),
            'claims_last_30_days':             rng.choice([0, 1, 2, 3], p=[0.45, 0.35, 0.15, 0.05]),
            'claims_last_7_days':              rng.choice([0, 1, 2],    p=[0.65, 0.28, 0.07]),
            'distance_from_zone_km':           float(np.clip(rng.exponential(2.5), 0, 12)),
            'time_since_last_claim_hours':     float(np.clip(rng.exponential(200) + 12, 4, 720)),
            'trigger_weather_match':           rng.choice([0, 1], p=[0.08, 0.92]),
            'other_riders_same_zone_claimed':  rng.choice([0, 1], p=[0.15, 0.85]),
            'claim_hour':                      rng.choice(range(8, 23)),
            'day_of_week':                     rng.integers(0, 7),
            'policy_age_days':                 int(np.clip(rng.exponential(45) + 7, 7, 365)),
            'is_fraudulent':                   0,
        })

    # ── Fraudulent claims ──────────────────────────────────────────────────
    fraud_patterns = [
        # Pattern A: GPS mismatch + no peers (40% of fraud)
        dict(claims_last_7=lambda: rng.choice([1, 2], p=[0.5, 0.5]),
             distance=lambda: float(np.clip(rng.normal(15, 5), 8, 35)),
             weather_match=0, others_claimed=0, hour=lambda: rng.choice(range(8, 22))),
        # Pattern B: High frequency + new policy (30% of fraud)
        dict(claims_last_7=lambda: rng.choice([3, 4, 5], p=[0.4, 0.4, 0.2]),
             distance=lambda: float(np.clip(rng.normal(4, 2), 0, 10)),
             weather_match=lambda: rng.choice([0, 1], p=[0.5, 0.5]),
             others_claimed=lambda: rng.choice([0, 1], p=[0.6, 0.4]),
             hour=lambda: rng.choice(range(2, 6))),
        # Pattern C: Night claim + weather mismatch (30% of fraud)
        dict(claims_last_7=lambda: rng.choice([0, 1, 2], p=[0.3, 0.4, 0.3]),
             distance=lambda: float(np.clip(rng.normal(8, 4), 2, 25)),
             weather_match=0,
             others_claimed=lambda: rng.choice([0, 1], p=[0.8, 0.2]),
             hour=lambda: rng.choice(list(range(0, 6)) + list(range(22, 24)))),
    ]

    pattern_weights = [0.40, 0.30, 0.30]
    for i in range(n_fraud):
        pat_idx = rng.choice(len(fraud_patterns), p=pattern_weights)
        p = fraud_patterns[pat_idx]
        _call = lambda v: v() if callable(v) else v
        rows.append({
            'claim_amount':                    rng.integers(80, 180) * 100,
            'rider_experience_months':         int(np.clip(rng.exponential(8) + 1, 1, 30)),
            'claims_last_30_days':             int(np.clip(_call(p['claims_last_7']) * 3, 0, 12)),
            'claims_last_7_days':              int(_call(p['claims_last_7'])),
            'distance_from_zone_km':           round(_call(p['distance']), 2),
            'time_since_last_claim_hours':     float(np.clip(rng.exponential(30) + 1, 1, 200)),
            'trigger_weather_match':           int(_call(p['weather_match'])),
            'other_riders_same_zone_claimed':  int(_call(p['others_claimed'])),
            'claim_hour':                      int(_call(p['hour'])),
            'day_of_week':                     rng.integers(0, 7),
            'policy_age_days':                 int(np.clip(rng.exponential(10) + 1, 1, 30)),
            'is_fraudulent':                   1,
        })

    df = pd.DataFrame(rows)
    # Shuffle
    return df.sample(frac=1, random_state=42).reset_index(drop=True)


# ─────────────────────────────────────────────────────────────────────────────
# 3. DISRUPTION HISTORY (2,000 rows)
# ─────────────────────────────────────────────────────────────────────────────

DISRUPTION_TYPES = ['HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding', 'SocialDisruption']

# Probability of each disruption type by city/season
CITY_DISRUPTION_PROBS = {
    'Mumbai':    {'monsoon': {'HeavyRain': 0.35, 'Flooding': 0.30, 'SocialDisruption': 0.20, 'ExtremeHeat': 0.05, 'SevereAQI': 0.10},
                  'winter':  {'HeavyRain': 0.10, 'Flooding': 0.05, 'SocialDisruption': 0.35, 'ExtremeHeat': 0.15, 'SevereAQI': 0.35},
                  'summer':  {'HeavyRain': 0.15, 'Flooding': 0.10, 'SocialDisruption': 0.30, 'ExtremeHeat': 0.25, 'SevereAQI': 0.20}},
    'Delhi':     {'winter':  {'SevereAQI': 0.55, 'ExtremeHeat': 0.05, 'HeavyRain': 0.05, 'SocialDisruption': 0.30, 'Flooding': 0.05},
                  'summer':  {'ExtremeHeat': 0.50, 'SevereAQI': 0.20, 'HeavyRain': 0.10, 'SocialDisruption': 0.15, 'Flooding': 0.05},
                  'monsoon': {'HeavyRain': 0.25, 'Flooding': 0.15, 'SevereAQI': 0.15, 'SocialDisruption': 0.30, 'ExtremeHeat': 0.15}},
    'Bangalore': {'monsoon': {'HeavyRain': 0.40, 'SocialDisruption': 0.35, 'Flooding': 0.15, 'ExtremeHeat': 0.05, 'SevereAQI': 0.05},
                  'winter':  {'SocialDisruption': 0.50, 'HeavyRain': 0.20, 'ExtremeHeat': 0.10, 'SevereAQI': 0.10, 'Flooding': 0.10},
                  'summer':  {'HeavyRain': 0.25, 'SocialDisruption': 0.35, 'ExtremeHeat': 0.20, 'SevereAQI': 0.10, 'Flooding': 0.10}},
    'Chennai':   {'winter':  {'HeavyRain': 0.35, 'Flooding': 0.35, 'ExtremeHeat': 0.10, 'SevereAQI': 0.10, 'SocialDisruption': 0.10},
                  'monsoon': {'HeavyRain': 0.30, 'Flooding': 0.25, 'ExtremeHeat': 0.15, 'SevereAQI': 0.15, 'SocialDisruption': 0.15},
                  'summer':  {'ExtremeHeat': 0.35, 'HeavyRain': 0.20, 'SevereAQI': 0.20, 'Flooding': 0.10, 'SocialDisruption': 0.15}},
    'Hyderabad': {'monsoon': {'HeavyRain': 0.30, 'Flooding': 0.30, 'ExtremeHeat': 0.15, 'SevereAQI': 0.15, 'SocialDisruption': 0.10},
                  'summer':  {'ExtremeHeat': 0.40, 'HeavyRain': 0.15, 'SevereAQI': 0.20, 'Flooding': 0.10, 'SocialDisruption': 0.15},
                  'winter':  {'SevereAQI': 0.30, 'ExtremeHeat': 0.15, 'HeavyRain': 0.15, 'SocialDisruption': 0.25, 'Flooding': 0.15}},
    'Kolkata':   {'monsoon': {'HeavyRain': 0.40, 'Flooding': 0.25, 'SocialDisruption': 0.20, 'SevereAQI': 0.10, 'ExtremeHeat': 0.05},
                  'winter':  {'SevereAQI': 0.35, 'SocialDisruption': 0.30, 'HeavyRain': 0.15, 'ExtremeHeat': 0.10, 'Flooding': 0.10},
                  'summer':  {'ExtremeHeat': 0.25, 'HeavyRain': 0.25, 'SevereAQI': 0.20, 'SocialDisruption': 0.20, 'Flooding': 0.10}},
    'Pune':      {'monsoon': {'HeavyRain': 0.45, 'Flooding': 0.25, 'SocialDisruption': 0.15, 'ExtremeHeat': 0.10, 'SevereAQI': 0.05},
                  'summer':  {'ExtremeHeat': 0.30, 'HeavyRain': 0.25, 'SocialDisruption': 0.25, 'SevereAQI': 0.10, 'Flooding': 0.10},
                  'winter':  {'SocialDisruption': 0.35, 'ExtremeHeat': 0.15, 'HeavyRain': 0.20, 'SevereAQI': 0.20, 'Flooding': 0.10}},
    'Ahmedabad': {'summer':  {'ExtremeHeat': 0.55, 'SevereAQI': 0.25, 'HeavyRain': 0.10, 'SocialDisruption': 0.05, 'Flooding': 0.05},
                  'monsoon': {'HeavyRain': 0.30, 'Flooding': 0.20, 'ExtremeHeat': 0.20, 'SevereAQI': 0.20, 'SocialDisruption': 0.10},
                  'winter':  {'SevereAQI': 0.30, 'ExtremeHeat': 0.20, 'SocialDisruption': 0.25, 'HeavyRain': 0.15, 'Flooding': 0.10}},
    'Jaipur':    {'summer':  {'ExtremeHeat': 0.50, 'SevereAQI': 0.25, 'HeavyRain': 0.10, 'SocialDisruption': 0.10, 'Flooding': 0.05},
                  'monsoon': {'HeavyRain': 0.35, 'Flooding': 0.20, 'ExtremeHeat': 0.20, 'SevereAQI': 0.15, 'SocialDisruption': 0.10},
                  'winter':  {'SevereAQI': 0.35, 'ExtremeHeat': 0.20, 'SocialDisruption': 0.20, 'HeavyRain': 0.15, 'Flooding': 0.10}},
    'Lucknow':   {'winter':  {'SevereAQI': 0.40, 'ExtremeHeat': 0.10, 'SocialDisruption': 0.25, 'HeavyRain': 0.15, 'Flooding': 0.10},
                  'summer':  {'ExtremeHeat': 0.45, 'SevereAQI': 0.25, 'HeavyRain': 0.10, 'SocialDisruption': 0.15, 'Flooding': 0.05},
                  'monsoon': {'HeavyRain': 0.30, 'Flooding': 0.20, 'ExtremeHeat': 0.15, 'SevereAQI': 0.20, 'SocialDisruption': 0.15}},
}

SEVERITY_MAP = {
    'HeavyRain':        ['Moderate', 'Severe', 'Extreme'],
    'ExtremeHeat':      ['Moderate', 'Severe', 'Extreme'],
    'SevereAQI':        ['Moderate', 'Severe', 'Extreme'],
    'Flooding':         ['Moderate', 'Severe', 'Extreme'],
    'SocialDisruption': ['Moderate', 'Severe'],
}


def generate_disruption_data(n: int = 2_000) -> pd.DataFrame:
    print(f"Generating {n} disruption history rows...")
    rng = np.random.default_rng(99)

    rows = []
    start_date = pd.Timestamp('2023-01-01')
    end_date   = pd.Timestamp('2025-12-31')
    date_range = pd.date_range(start_date, end_date, freq='D')

    for _ in range(n):
        city   = rng.choice(CITIES, p=CITY_WEIGHTS)
        date   = pd.Timestamp(rng.choice(date_range))
        month  = date.month
        dow    = date.dayofweek

        if month in [6, 7, 8, 9]:
            season = 'monsoon'
        elif month in [11, 12, 1, 2]:
            season = 'winter'
        else:
            season = 'summer'

        probs_map = CITY_DISRUPTION_PROBS[city][season]
        d_type    = rng.choice(list(probs_map.keys()), p=list(probs_map.values()))

        aqi, rain, temp = sample_weather(city, season, 1)

        # Trigger-specific adjustments — overwrite feature vars so stored values match severity
        # Thresholds tuned for ~50% Moderate / ~35% Severe / ~15% Extreme balance
        if d_type == 'HeavyRain':
            rain = np.clip(rng.normal(85, 35), 30, 220)
            actual_val, threshold = float(rain), 64.0
            if actual_val >= 130: severity = 'Extreme'
            elif actual_val >= 90: severity = 'Severe'
            else: severity = 'Moderate'
        elif d_type == 'ExtremeHeat':
            temp = np.clip(rng.normal(46, 2.5), 43, 54)   # overwrite temp
            actual_val, threshold = float(temp), 48.0
            if actual_val >= 49.5: severity = 'Extreme'
            elif actual_val >= 46.5: severity = 'Severe'
            else: severity = 'Moderate'
        elif d_type == 'SevereAQI':
            aqi = np.clip(rng.normal(450, 70), 400, 620)   # overwrite aqi
            actual_val, threshold = float(aqi), 400.0
            if actual_val >= 510: severity = 'Extreme'
            elif actual_val >= 450: severity = 'Severe'
            else: severity = 'Moderate'
        elif d_type == 'Flooding':
            rain = np.clip(rng.normal(9, 3), 6, 20)        # overwrite rain (hours of sustained rain)
            actual_val, threshold = float(rain), 6.0
            if actual_val >= 13: severity = 'Extreme'
            elif actual_val >= 9.5: severity = 'Severe'
            else: severity = 'Moderate'
        else:  # SocialDisruption
            actual_val, threshold = float(np.clip(rng.normal(9, 3), 4, 20)), 4.0
            if actual_val >= 13: severity = 'Extreme'
            elif actual_val >= 9.5: severity = 'Severe'
            else: severity = 'Moderate'

        duration_hrs     = float(np.clip(rng.normal(7, 3), 2, 20))
        riders_affected  = int(np.clip(rng.poisson(12), 1, 80))
        avg_payout       = rng.integers(600, 1800) * 100 / 100  # rupees
        total_payout     = int(riders_affected * avg_payout)
        has_disruption   = 1  # all rows are actual disruption events

        rows.append({
            'date':              date.strftime('%Y-%m-%d'),
            'city':              city,
            'month':             month,
            'day_of_week':       dow,
            'season':            season,
            'disruption_type':   d_type,
            'severity':          severity,
            'duration_hours':    round(duration_hrs, 1),
            'rainfall_mm':       round(float(rain[0] if hasattr(rain, '__len__') else rain), 1),
            'temperature_c':     round(float(temp[0] if hasattr(temp, '__len__') else temp), 1),
            'aqi':               round(float(aqi[0] if hasattr(aqi, '__len__') else aqi), 0),
            'wind_speed_ms':     round(float(np.clip(rng.normal(4, 2), 0, 15)), 1),
            'riders_affected':   riders_affected,
            'total_payout_inr':  total_payout,
            'actual_value':      round(actual_val, 2),
            'threshold':         threshold,
            'has_disruption':    has_disruption,
        })

    return pd.DataFrame(rows)


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    out_dir = Path(__file__).parent
    out_dir.mkdir(parents=True, exist_ok=True)

    df_premium = generate_premium_data(10_000)
    df_premium.to_csv(out_dir / 'premium_training_data.csv', index=False)
    print(f"  ✓ premium_training_data.csv — {len(df_premium)} rows")
    print(f"    Premium range: ₹{df_premium.weekly_premium.min():.1f} – ₹{df_premium.weekly_premium.max():.1f}/week")
    print(f"    Risk score range: {df_premium.risk_score.min():.1f} – {df_premium.risk_score.max():.1f}")

    df_fraud = generate_fraud_data(5_000, 0.08)
    df_fraud.to_csv(out_dir / 'fraud_training_data.csv', index=False)
    fraud_pct = df_fraud.is_fraudulent.mean() * 100
    print(f"  ✓ fraud_training_data.csv — {len(df_fraud)} rows ({fraud_pct:.1f}% fraud)")

    df_disruption = generate_disruption_data(2_000)
    df_disruption.to_csv(out_dir / 'disruption_history.csv', index=False)
    print(f"  ✓ disruption_history.csv — {len(df_disruption)} rows")
    print(f"    Disruption types: {df_disruption.disruption_type.value_counts().to_dict()}")

    print('\n✅ All training data generated successfully.')
