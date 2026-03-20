export interface CityConfig {
  name: string;
  owmName: string;          // OpenWeatherMap city name
  state: string;
  lat: number;
  lng: number;
  timezone: string;
  premiumMultiplier: number;
  baseRiskScore: number;
  topRisks: string[];
  floodProneZones: string[];
  zones: string[];          // All delivery zones
  avgAQI: { winter: number; summer: number; monsoon: number };
  avgRainfall: { monsoon: number; winter: number; summer: number }; // mm
}

export const CITIES: Record<string, CityConfig> = {
  Mumbai: {
    name: 'Mumbai', owmName: 'Mumbai,IN', state: 'Maharashtra',
    lat: 19.0760, lng: 72.8777, timezone: 'Asia/Kolkata',
    premiumMultiplier: 1.35, baseRiskScore: 72,
    topRisks: ['Flooding', 'HeavyRain', 'SocialDisruption'],
    floodProneZones: ['Andheri', 'Borivali', 'Dadar', 'Sion', 'Kurla', 'Chembur', 'Dharavi'],
    zones: ['Andheri West', 'Andheri East', 'Borivali', 'Dadar', 'Sion', 'Kurla', 'Chembur', 'Malad', 'Vile Parle', 'Thane'],
    avgAQI: { winter: 148, summer: 89, monsoon: 62 },
    avgRainfall: { monsoon: 2166, winter: 3, summer: 15 },
  },
  Delhi: {
    name: 'Delhi', owmName: 'Delhi,IN', state: 'Delhi',
    lat: 28.6139, lng: 77.2090, timezone: 'Asia/Kolkata',
    premiumMultiplier: 1.45, baseRiskScore: 88,
    topRisks: ['SevereAQI', 'ExtremeHeat', 'SocialDisruption'],
    floodProneZones: ['Yamuna Khadar', 'Mayur Vihar', 'Patparganj', 'Loni Road'],
    zones: ['Dwarka', 'Rohini', 'Pitampura', 'Janakpuri', 'Karol Bagh', 'Saket', 'Lajpat Nagar', 'Greater Kailash', 'Hauz Khas'],
    avgAQI: { winter: 312, summer: 180, monsoon: 95 },
    avgRainfall: { monsoon: 797, winter: 22, summer: 28 },
  },
  Bangalore: {
    name: 'Bangalore', owmName: 'Bangalore,IN', state: 'Karnataka',
    lat: 12.9716, lng: 77.5946, timezone: 'Asia/Kolkata',
    premiumMultiplier: 0.90, baseRiskScore: 34,
    topRisks: ['HeavyRain', 'SocialDisruption'],
    floodProneZones: ['Ejipura', 'Silk Board', 'Hebbal', 'KR Puram'],
    zones: ['Koramangala', 'Indiranagar', 'Whitefield', 'Jayanagar', 'Marathahalli', 'Electronic City', 'HSR Layout', 'BTM Layout'],
    avgAQI: { winter: 98, summer: 75, monsoon: 55 },
    avgRainfall: { monsoon: 972, winter: 38, summer: 45 },
  },
  Chennai: {
    name: 'Chennai', owmName: 'Chennai,IN', state: 'Tamil Nadu',
    lat: 13.0827, lng: 80.2707, timezone: 'Asia/Kolkata',
    premiumMultiplier: 1.20, baseRiskScore: 68,
    topRisks: ['Flooding', 'HeavyRain', 'ExtremeHeat'],
    floodProneZones: ['Adyar', 'Velachery', 'Tambaram', 'Mudichur', 'Sholinganallur', 'Porur'],
    zones: ['Velachery', 'T. Nagar', 'Adyar', 'Anna Nagar', 'Tambaram', 'Porur', 'Sholinganallur'],
    avgAQI: { winter: 118, summer: 102, monsoon: 72 },
    avgRainfall: { monsoon: 1400, winter: 290, summer: 82 },
  },
  Hyderabad: {
    name: 'Hyderabad', owmName: 'Hyderabad,IN', state: 'Telangana',
    lat: 17.3850, lng: 78.4867, timezone: 'Asia/Kolkata',
    premiumMultiplier: 1.10, baseRiskScore: 55,
    topRisks: ['Flooding', 'HeavyRain', 'ExtremeHeat'],
    floodProneZones: ['Kukatpally', 'Madhapur', 'LB Nagar', 'Falaknuma', 'Moosarambagh'],
    zones: ['Kukatpally', 'Madhapur', 'LB Nagar', 'Gachibowli', 'Secunderabad', 'Uppal', 'Miyapur'],
    avgAQI: { winter: 142, summer: 115, monsoon: 68 },
    avgRainfall: { monsoon: 790, winter: 15, summer: 30 },
  },
  Kolkata: {
    name: 'Kolkata', owmName: 'Kolkata,IN', state: 'West Bengal',
    lat: 22.5726, lng: 88.3639, timezone: 'Asia/Kolkata',
    premiumMultiplier: 1.25, baseRiskScore: 64,
    topRisks: ['HeavyRain', 'Flooding', 'SocialDisruption'],
    floodProneZones: ['Howrah', 'Shibpur', 'Tiljala', 'Topsia', 'Garden Reach'],
    zones: ['Salt Lake', 'Park Street', 'Howrah', 'Ballygunge', 'New Town', 'Rajarhat'],
    avgAQI: { winter: 198, summer: 105, monsoon: 75 },
    avgRainfall: { monsoon: 1582, winter: 28, summer: 65 },
  },
  Pune: {
    name: 'Pune', owmName: 'Pune,IN', state: 'Maharashtra',
    lat: 18.5204, lng: 73.8567, timezone: 'Asia/Kolkata',
    premiumMultiplier: 1.05, baseRiskScore: 48,
    topRisks: ['HeavyRain', 'Flooding'],
    floodProneZones: ['Katraj', 'Sinhagad Road', 'Kothrud Low-lying', 'Sangamwadi'],
    zones: ['Kothrud', 'Hinjawadi', 'Shivajinagar', 'Viman Nagar', 'Pimple Saudagar', 'Wakad', 'Baner'],
    avgAQI: { winter: 122, summer: 95, monsoon: 58 },
    avgRainfall: { monsoon: 722, winter: 10, summer: 18 },
  },
  Ahmedabad: {
    name: 'Ahmedabad', owmName: 'Ahmedabad,IN', state: 'Gujarat',
    lat: 23.0225, lng: 72.5714, timezone: 'Asia/Kolkata',
    premiumMultiplier: 1.00, baseRiskScore: 51,
    topRisks: ['ExtremeHeat', 'SevereAQI'],
    floodProneZones: ['Odhav', 'Vatva', 'Nikol'],
    zones: ['Navrangpura', 'Bopal', 'Satellite', 'Prahlad Nagar', 'Maninagar', 'Vastrapur'],
    avgAQI: { winter: 155, summer: 178, monsoon: 82 },
    avgRainfall: { monsoon: 482, winter: 4, summer: 5 },
  },
  Jaipur: {
    name: 'Jaipur', owmName: 'Jaipur,IN', state: 'Rajasthan',
    lat: 26.9124, lng: 75.7873, timezone: 'Asia/Kolkata',
    premiumMultiplier: 1.15, baseRiskScore: 71,
    topRisks: ['ExtremeHeat', 'HeavyRain'],
    floodProneZones: ['Mansarovar Low-lying', 'Sanganer', 'Murlipura'],
    zones: ['Vaishali Nagar', 'Malviya Nagar', 'C-Scheme', 'Mansarovar', 'Jagatpura', 'Tonk Road'],
    avgAQI: { winter: 172, summer: 210, monsoon: 88 },
    avgRainfall: { monsoon: 644, winter: 12, summer: 8 },
  },
  Lucknow: {
    name: 'Lucknow', owmName: 'Lucknow,IN', state: 'Uttar Pradesh',
    lat: 26.8467, lng: 80.9462, timezone: 'Asia/Kolkata',
    premiumMultiplier: 1.15, baseRiskScore: 63,
    topRisks: ['ExtremeHeat', 'SevereAQI', 'HeavyRain'],
    floodProneZones: ['Gomti Nagar Extension', 'Rajajipuram', 'Telibagh'],
    zones: ['Hazratganj', 'Gomti Nagar', 'Aliganj', 'Indira Nagar', 'Mahanagar', 'Vikas Nagar'],
    avgAQI: { winter: 245, summer: 168, monsoon: 98 },
    avgRainfall: { monsoon: 825, winter: 20, summer: 18 },
  },
};

export const SUPPORTED_CITIES = Object.keys(CITIES);

export const getCityConfig = (cityName: string): CityConfig | null =>
  CITIES[cityName] ?? null;

/** Returns the current meteorological season for India */
export const getCurrentSeason = (): 'monsoon' | 'winter' | 'summer' => {
  const month = new Date().getMonth() + 1; // 1-12
  if (month >= 6 && month <= 9) return 'monsoon';
  if (month >= 11 || month <= 2) return 'winter';
  return 'summer';
};
