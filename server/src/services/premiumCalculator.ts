import { getCurrentSeason, getCityConfig } from '../config/cities';

export type PlanType = 'Basic' | 'Standard' | 'Premium';

export interface PremiumBreakdown {
  planType: PlanType;
  basePremiumPaise: number;
  cityMultiplier: number;
  seasonalMultiplier: number;
  experienceDiscount: number;
  claimsAdjustment: number;
  finalPremiumPaise: number;
  finalPremiumINR: number;
  coverageLimitPaise: number;
  coveredDisruptions: string[];
  savings: number; // paise saved vs no discounts
}

const BASE_PREMIUM_PAISE: Record<PlanType, number> = {
  Basic:    3500,
  Standard: 5500,
  Premium:  7500,
};

export const PLAN_CONFIG: Record<PlanType, { disruptions: string[]; coverageLimit: number }> = {
  Basic:    { disruptions: ['HeavyRain', 'ExtremeHeat'],                                              coverageLimit: 80000 },
  Standard: { disruptions: ['HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding'],                     coverageLimit: 120000 },
  Premium:  { disruptions: ['HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding', 'SocialDisruption'], coverageLimit: 180000 },
};

/** Seasonal multiplier — monsoon/winter increases risk in many cities */
function getSeasonalMultiplier(city: string, season: string): number {
  const highRainCities  = ['Mumbai', 'Kolkata', 'Chennai', 'Hyderabad', 'Pune', 'Bangalore'];
  const highWinterCities = ['Delhi', 'Lucknow', 'Jaipur'];

  if (season === 'monsoon' && highRainCities.includes(city))  return 1.15;
  if (season === 'winter'  && highWinterCities.includes(city)) return 1.20;
  if (season === 'summer'  && ['Jaipur', 'Delhi', 'Ahmedabad', 'Lucknow'].includes(city)) return 1.10;
  return 1.00;
}

function getExperienceDiscount(experienceMonths: number): number {
  if (experienceMonths > 24) return 0.90;
  if (experienceMonths > 12) return 0.95;
  return 1.00;
}

function getClaimsAdjustment(recentClaimsCount: number): number {
  if (recentClaimsCount === 0) return 1.00;
  if (recentClaimsCount === 1) return 1.05;
  if (recentClaimsCount === 2) return 1.10;
  return 1.20;
}

export function calculateWeeklyPremium(
  city: string,
  plan: PlanType,
  experienceMonths: number,
  recentClaimsCount = 0,
): PremiumBreakdown {
  const cityConfig = getCityConfig(city);
  const cityMult = cityConfig?.premiumMultiplier ?? 1.0;
  const season = getCurrentSeason();
  const seasonMult = getSeasonalMultiplier(city, season);
  const expDiscount = getExperienceDiscount(experienceMonths);
  const claimsAdj = getClaimsAdjustment(recentClaimsCount);

  const base = BASE_PREMIUM_PAISE[plan];
  const raw = base * cityMult * seasonMult * expDiscount * claimsAdj;
  const final = Math.ceil(raw / 100) * 100; // round up to nearest ₹1

  const noDiscountPrice = Math.ceil(base * cityMult * seasonMult / 100) * 100;
  const savings = Math.max(0, noDiscountPrice - final);

  return {
    planType: plan,
    basePremiumPaise: base,
    cityMultiplier: cityMult,
    seasonalMultiplier: seasonMult,
    experienceDiscount: expDiscount,
    claimsAdjustment: claimsAdj,
    finalPremiumPaise: final,
    finalPremiumINR: final / 100,
    coverageLimitPaise: PLAN_CONFIG[plan].coverageLimit,
    coveredDisruptions: PLAN_CONFIG[plan].disruptions,
    savings,
  };
}

export function getAllPlansForCity(city: string, experienceMonths: number, recentClaimsCount = 0) {
  return (['Basic', 'Standard', 'Premium'] as PlanType[]).map(plan =>
    calculateWeeklyPremium(city, plan, experienceMonths, recentClaimsCount)
  );
}
