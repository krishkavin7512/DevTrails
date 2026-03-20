export const MOCK_RIDER = {
  _id: 'demo-rider-001',
  name: 'Rahul Sharma',
  phone: '9876543210',
  email: 'rahul.sharma@gmail.com',
  city: 'Mumbai',
  platform: 'Swiggy',
  vehicleType: 'motorcycle',
  preferredShift: 'evening',
  avgWeeklyEarnings: 5500,
  avgDailyHours: 8,
  experienceMonths: 24,
  riskTier: 'Medium',
  riskScore: 52,
  historicalClaimsCount: 3,
  historicalDisruptionFreq: 0.28,
  zone: 'Andheri West',
  pincode: '400053',
};

export const MOCK_POLICY = {
  _id: 'demo-policy-001',
  planType: 'Standard',
  weeklyPremium: 5500,
  coverageLimit: 1500000,
  coveredDisruptions: ['HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding'],
  status: 'Active',
  startDate: '2026-02-15T00:00:00Z',
  endDate: '2026-05-15T00:00:00Z',
  policyNumber: 'RC-MUM-2026-001234',
  renewalCount: 1,
  autoRenew: true,
};

export const MOCK_CLAIMS = [
  {
    _id: 'clm-001', claimNumber: 'CLM-2026-0041', triggerType: 'HeavyRain',
    payoutAmount: 120000, status: 'Paid',
    createdAt: '2026-03-05T14:30:00Z', estimatedLostHours: 6, fraudScore: 8,
    triggerData: { parameter: 'rainfall_mm_hr', threshold: 64, actualValue: 78.5, dataSource: 'OpenWeatherMap', timestamp: '2026-03-05T14:00:00Z', location: { lat: 19.1, lng: 72.8 } },
  },
  {
    _id: 'clm-002', claimNumber: 'CLM-2026-0028', triggerType: 'SevereAQI',
    payoutAmount: 85000, status: 'Paid',
    createdAt: '2026-02-28T09:00:00Z', estimatedLostHours: 4, fraudScore: 12,
    triggerData: { parameter: 'aqi', threshold: 400, actualValue: 435, dataSource: 'OpenWeatherMap', timestamp: '2026-02-28T08:00:00Z', location: { lat: 19.07, lng: 72.85 } },
  },
  {
    _id: 'clm-003', claimNumber: 'CLM-2026-0055', triggerType: 'ExtremeHeat',
    payoutAmount: 95000, status: 'AutoInitiated',
    createdAt: '2026-03-18T11:00:00Z', estimatedLostHours: 5, fraudScore: 5,
    triggerData: { parameter: 'feels_like_c', threshold: 48, actualValue: 49.2, dataSource: 'OpenWeatherMap', timestamp: '2026-03-18T10:30:00Z', location: { lat: 19.12, lng: 72.82 } },
  },
  {
    _id: 'clm-004', claimNumber: 'CLM-2026-0009', triggerType: 'Flooding',
    payoutAmount: 150000, status: 'Approved',
    createdAt: '2026-01-15T07:00:00Z', estimatedLostHours: 9, fraudScore: 18,
    triggerData: { parameter: 'rain_duration_hrs', threshold: 6, actualValue: 8.5, dataSource: 'OpenWeatherMap', timestamp: '2026-01-15T06:00:00Z', location: { lat: 19.08, lng: 72.87 } },
  },
  {
    _id: 'clm-005', claimNumber: 'CLM-2026-0003', triggerType: 'HeavyRain',
    payoutAmount: 0, status: 'Rejected',
    createdAt: '2026-01-05T16:00:00Z', estimatedLostHours: 0, fraudScore: 72,
    triggerData: { parameter: 'rainfall_mm_hr', threshold: 64, actualValue: 62.1, dataSource: 'OpenWeatherMap', timestamp: '2026-01-05T15:30:00Z', location: { lat: 19.04, lng: 72.77 } },
  },
];

export const MOCK_WEATHER = {
  city: 'Mumbai', temperature: 32, feelsLike: 36, humidity: 78,
  description: 'Partly Cloudy', windSpeed: 12, rainfall: 0.0, aqi: 145,
  isDisruptionActive: false, lastUpdated: new Date().toISOString(),
};

export const MOCK_CITY_WEATHER: Record<string, { temp: number; aqi: number; condition: string; rainfall: number; wind: number; triggers: string[]; severity: string | null }> = {
  Delhi:     { temp: 38, aqi: 287, condition: 'Hazy',         rainfall: 0,   wind: 8,  triggers: ['SevereAQI'], severity: 'Moderate' },
  Mumbai:    { temp: 32, aqi: 145, condition: 'Partly Cloudy', rainfall: 0,   wind: 14, triggers: [], severity: null },
  Bangalore: { temp: 26, aqi: 62,  condition: 'Mostly Clear',  rainfall: 0.2, wind: 9,  triggers: [], severity: null },
  Hyderabad: { temp: 35, aqi: 110, condition: 'Sunny',         rainfall: 0,   wind: 11, triggers: [], severity: null },
  Chennai:   { temp: 33, aqi: 98,  condition: 'Humid',         rainfall: 0,   wind: 13, triggers: [], severity: null },
  Pune:      { temp: 29, aqi: 78,  condition: 'Clear',         rainfall: 0,   wind: 7,  triggers: [], severity: null },
  Kolkata:   { temp: 34, aqi: 168, condition: 'Hazy',          rainfall: 2.1, wind: 10, triggers: [], severity: null },
  Jaipur:    { temp: 41, aqi: 195, condition: 'Dusty',         rainfall: 0,   wind: 6,  triggers: ['ExtremeHeat'], severity: 'Moderate' },
  Ahmedabad: { temp: 43, aqi: 155, condition: 'Hot',           rainfall: 0,   wind: 8,  triggers: ['ExtremeHeat'], severity: 'Moderate' },
  Lucknow:   { temp: 37, aqi: 230, condition: 'Hazy',          rainfall: 0,   wind: 5,  triggers: ['SevereAQI'], severity: null },
};

export const MOCK_DISRUPTIONS = [
  { _id: 'evt-001', city: 'Delhi', triggerType: 'SevereAQI', severity: 'Severe', title: 'Air Quality Alert — Delhi',
    description: 'AQI exceeded 400 threshold across central Delhi zones.', isActive: true,
    startTime: new Date(Date.now() - 3 * 3600000).toISOString(), affectedRiders: 234, totalPayouts: 25000000,
    triggerData: { parameter: 'aqi', actualValue: 456, threshold: 400 } },
  { _id: 'evt-002', city: 'Jaipur', triggerType: 'ExtremeHeat', severity: 'Moderate', title: 'Extreme Heat Warning — Jaipur',
    description: 'Feels-like temperature exceeding 48°C.', isActive: true,
    startTime: new Date(Date.now() - 1.5 * 3600000).toISOString(), affectedRiders: 89, totalPayouts: 8400000,
    triggerData: { parameter: 'feels_like_c', actualValue: 49.1, threshold: 48 } },
];

export const MOCK_ANALYTICS = {
  overview: { totalRiders: 12847, activeRiders: 11234, activePolicies: 9876,
    weeklyRevenuePaise: 54318000, weeklyPayoutsPaise: 23400000, lossRatio: 43.1,
    fraudDetectionRate: 3.2, avgPayoutMinutes: 1.8 },
  weeklyTrend: [
    { week: 'Jan 27', revenue: 420, payouts: 180 },
    { week: 'Feb 3',  revenue: 450, payouts: 210 },
    { week: 'Feb 10', revenue: 480, payouts: 195 },
    { week: 'Feb 17', revenue: 460, payouts: 240 },
    { week: 'Feb 24', revenue: 510, payouts: 220 },
    { week: 'Mar 3',  revenue: 520, payouts: 185 },
    { week: 'Mar 10', revenue: 540, payouts: 210 },
    { week: 'Mar 17', revenue: 543, payouts: 234 },
  ],
  claimsByType: [
    { type: 'HeavyRain', count: 1234, pct: 36 },
    { type: 'SevereAQI', count: 876, pct: 26 },
    { type: 'ExtremeHeat', count: 654, pct: 19 },
    { type: 'Flooding', count: 432, pct: 13 },
    { type: 'SocialDisruption', count: 234, pct: 7 },
  ],
  riskDistribution: [
    { tier: 'Low',      count: 2340, pct: 23.7 },
    { tier: 'Medium',   count: 4560, pct: 46.2 },
    { tier: 'High',     count: 2100, pct: 21.3 },
    { tier: 'VeryHigh', count: 876,  pct: 8.8  },
  ],
};
