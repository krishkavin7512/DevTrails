import WeatherData from '../models/WeatherData';
import { getCityConfig, getCurrentSeason } from '../config/cities';

const OWM_BASE = 'https://api.openweathermap.org/data/2.5';
const CACHE_TTL_CURRENT_MS  = 15 * 60_000;  // 15 minutes
const CACHE_TTL_FORECAST_MS = 60 * 60_000;  // 1 hour

export interface WeatherSnapshot {
  city: string;
  temperature: number;
  feelsLike: number;
  humidity: number;
  rainfall: number;   // mm/hr
  windSpeed: number;  // m/s
  weatherCondition: string;
  description: string;
  aqi: number;
  pm25: number;
  pm10: number;
  isDisruptionActive: boolean;
  disruptionSeverity: 'None' | 'Mild' | 'Moderate' | 'Severe' | 'Extreme';
  fetchedAt: Date;
  source: string;
}

export interface ForecastDay {
  date: string;
  tempMin: number;
  tempMax: number;
  rainfall: number;
  weatherCondition: string;
  description: string;
  humidity: number;
}

// ─── PM2.5 → CPCB AQI approximation ─────────────────────────────────────────
function pm25ToAQI(pm25: number): number {
  if (pm25 <= 30)  return Math.round((pm25 / 30) * 100);
  if (pm25 <= 60)  return Math.round(100 + ((pm25 - 30) / 30) * 100);
  if (pm25 <= 90)  return Math.round(200 + ((pm25 - 60) / 30) * 100);
  if (pm25 <= 120) return Math.round(300 + ((pm25 - 90) / 30) * 100);
  return Math.round(400 + ((pm25 - 120) / 30) * 100);
}

// ─── Mock data fallback (realistic for March / spring India) ──────────────────
function getMockWeather(city: string): WeatherSnapshot {
  const season = getCurrentSeason();
  const mocks: Record<string, Partial<WeatherSnapshot>> = {
    Mumbai:    { temperature: 32, feelsLike: 37, humidity: 80, rainfall: 0,  windSpeed: 3.8, aqi: 92,  pm25: 48,  pm10: 82,  weatherCondition: 'Partly Cloudy', description: 'Warm and humid' },
    Delhi:     { temperature: 24, feelsLike: 23, humidity: 55, rainfall: 0,  windSpeed: 2.1, aqi: 198, pm25: 128, pm10: 182, weatherCondition: 'Haze',          description: 'Hazy conditions, poor AQI' },
    Bangalore: { temperature: 27, feelsLike: 28, humidity: 60, rainfall: 0,  windSpeed: 3.2, aqi: 62,  pm25: 28,  pm10: 45,  weatherCondition: 'Clear',         description: 'Pleasant and clear' },
    Chennai:   { temperature: 34, feelsLike: 40, humidity: 76, rainfall: 2,  windSpeed: 4.1, aqi: 98,  pm25: 52,  pm10: 88,  weatherCondition: 'Cloudy',        description: 'Hot and humid' },
    Hyderabad: { temperature: 36, feelsLike: 38, humidity: 48, rainfall: 0,  windSpeed: 3.5, aqi: 115, pm25: 62,  pm10: 98,  weatherCondition: 'Sunny',         description: 'Hot afternoon' },
    Kolkata:   { temperature: 30, feelsLike: 34, humidity: 72, rainfall: 5,  windSpeed: 4.5, aqi: 135, pm25: 72,  pm10: 110, weatherCondition: 'Overcast',      description: 'Cloudy with drizzle' },
    Pune:      { temperature: 29, feelsLike: 31, humidity: 58, rainfall: 0,  windSpeed: 3.1, aqi: 78,  pm25: 38,  pm10: 62,  weatherCondition: 'Clear',         description: 'Warm and pleasant' },
    Ahmedabad: { temperature: 38, feelsLike: 41, humidity: 28, rainfall: 0,  windSpeed: 6.2, aqi: 148, pm25: 82,  pm10: 125, weatherCondition: 'Sunny',         description: 'Very hot and dry' },
    Jaipur:    { temperature: 35, feelsLike: 37, humidity: 32, rainfall: 0,  windSpeed: 7.1, aqi: 175, pm25: 95,  pm10: 145, weatherCondition: 'Dusty',         description: 'Hot and dusty' },
    Lucknow:   { temperature: 33, feelsLike: 35, humidity: 42, rainfall: 0,  windSpeed: 2.8, aqi: 188, pm25: 115, pm10: 168, weatherCondition: 'Hazy',          description: 'Hazy, moderate AQI' },
  };

  const base = mocks[city] ?? mocks['Mumbai']!;
  const disruption = evaluateDisruptionSeverity(
    (base.rainfall ?? 0),
    (base.temperature ?? 30),
    (base.aqi ?? 100),
  );

  return {
    city,
    temperature: base.temperature ?? 30,
    feelsLike:   base.feelsLike   ?? 33,
    humidity:    base.humidity    ?? 60,
    rainfall:    base.rainfall    ?? 0,
    windSpeed:   base.windSpeed   ?? 3,
    weatherCondition: base.weatherCondition ?? 'Clear',
    description: base.description ?? '',
    aqi:   base.aqi   ?? 100,
    pm25:  base.pm25  ?? 50,
    pm10:  base.pm10  ?? 80,
    isDisruptionActive: disruption !== 'None',
    disruptionSeverity: disruption,
    fetchedAt: new Date(),
    source: 'mock_data',
  } as WeatherSnapshot;
}

function evaluateDisruptionSeverity(
  rainfall: number,
  temperature: number,
  aqi: number,
): 'None' | 'Mild' | 'Moderate' | 'Severe' | 'Extreme' {
  if (rainfall > 100 || temperature > 47 || aqi > 500) return 'Extreme';
  if (rainfall > 64  || temperature > 45 || aqi > 400) return 'Severe';
  if (rainfall > 30  || temperature > 42 || aqi > 300) return 'Moderate';
  if (rainfall > 15  || temperature > 38 || aqi > 200) return 'Mild';
  return 'None';
}

// ─── OpenWeatherMap fetchers ──────────────────────────────────────────────────

async function owmFetch<T>(url: string): Promise<T | null> {
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) return null;
    return (await res.json()) as T;
  } catch {
    return null;
  }
}

async function fetchFromOWM(city: string): Promise<WeatherSnapshot | null> {
  const apiKey = process.env.OPENWEATHERMAP_API_KEY;
  if (!apiKey) return null;

  const cityConf = getCityConfig(city);
  if (!cityConf) return null;

  // Parallel fetch: current weather + AQI
  const [weatherRaw, aqiRaw] = await Promise.all([
    owmFetch<any>(`${OWM_BASE}/weather?q=${encodeURIComponent(cityConf.owmName)}&appid=${apiKey}&units=metric`),
    owmFetch<any>(`${OWM_BASE}/air_pollution?lat=${cityConf.lat}&lon=${cityConf.lng}&appid=${apiKey}`),
  ]);

  if (!weatherRaw) return null;

  const rainfall = (weatherRaw.rain?.['1h'] ?? weatherRaw.rain?.['3h'] ?? 0) as number;
  const temp     = weatherRaw.main.temp as number;
  const feelsLike= weatherRaw.main.feels_like as number;
  const humidity = weatherRaw.main.humidity as number;
  const windSpeed= weatherRaw.wind?.speed as number ?? 0;
  const condition= weatherRaw.weather?.[0]?.main ?? 'Unknown';
  const desc     = weatherRaw.weather?.[0]?.description ?? '';

  const aqiList  = aqiRaw?.list?.[0];
  const pm25     = (aqiList?.components?.pm2_5 ?? 0) as number;
  const pm10     = (aqiList?.components?.pm10  ?? 0) as number;
  const aqi      = pm25ToAQI(pm25);

  const severity = evaluateDisruptionSeverity(rainfall, temp, aqi);

  return {
    city, temperature: temp, feelsLike, humidity,
    rainfall, windSpeed,
    weatherCondition: condition, description: desc,
    aqi, pm25, pm10,
    isDisruptionActive: severity !== 'None',
    disruptionSeverity: severity,
    fetchedAt: new Date(),
    source: 'OpenWeatherMap',
  };
}

// ─── Public API ───────────────────────────────────────────────────────────────

export async function getCurrentWeather(city: string): Promise<WeatherSnapshot> {
  // Check cache
  const cached = await WeatherData.findOne({
    city,
    dataType: 'Weather',
    fetchedAt: { $gte: new Date(Date.now() - CACHE_TTL_CURRENT_MS) },
  }).sort({ fetchedAt: -1 });

  if (cached) {
    return {
      city: cached.city,
      temperature: cached.data.temperature,
      feelsLike:   cached.data.feelsLike,
      humidity:    cached.data.humidity,
      rainfall:    cached.data.rainfall,
      windSpeed:   cached.data.windSpeed,
      weatherCondition: cached.data.weatherCondition,
      description: cached.data.description,
      aqi:    cached.data.aqi,
      pm25:   cached.data.pm25,
      pm10:   cached.data.pm10,
      isDisruptionActive: cached.isDisruptionActive,
      disruptionSeverity: cached.disruptionSeverity,
      fetchedAt: cached.fetchedAt,
      source: cached.source + ' (cached)',
    };
  }

  // Fetch live or fall back to mock
  const fresh = (await fetchFromOWM(city)) ?? getMockWeather(city);

  // Persist to cache
  await WeatherData.findOneAndUpdate(
    { city, dataType: 'Weather' },
    {
      city, dataType: 'Weather',
      pincode: getCityConfig(city)?.floodProneZones[0] ?? '000000',
      data: {
        temperature:      fresh.temperature,
        feelsLike:        fresh.feelsLike,
        humidity:         fresh.humidity,
        rainfall:         fresh.rainfall,
        windSpeed:        fresh.windSpeed,
        aqi:              fresh.aqi,
        pm25:             fresh.pm25,
        pm10:             fresh.pm10,
        weatherCondition: fresh.weatherCondition,
        description:      fresh.description,
      },
      isDisruptionActive: fresh.isDisruptionActive,
      disruptionSeverity: fresh.disruptionSeverity,
      fetchedAt: fresh.fetchedAt,
      source: fresh.source,
    },
    { upsert: true, new: true }
  );

  return fresh;
}

export async function getAQI(city: string): Promise<{
  aqi: number; pm25: number; pm10: number;
  severity: string; description: string; source: string;
}> {
  const weather = await getCurrentWeather(city);
  const aqiLevels: Record<string, string> = {
    Good:       '0-50',
    Satisfactory:'51-100',
    Moderate:   '101-200',
    Poor:       '201-300',
    VeryPoor:   '301-400',
    Severe:     '401+',
  };

  let level = 'Good';
  if (weather.aqi > 400) level = 'Severe';
  else if (weather.aqi > 300) level = 'VeryPoor';
  else if (weather.aqi > 200) level = 'Poor';
  else if (weather.aqi > 100) level = 'Moderate';
  else if (weather.aqi > 50)  level = 'Satisfactory';

  return {
    aqi:   weather.aqi,
    pm25:  weather.pm25,
    pm10:  weather.pm10,
    severity: level,
    description: `AQI ${weather.aqi} — ${level} (CPCB Scale: ${aqiLevels[level]})`,
    source: weather.source,
  };
}

export async function getForecast(city: string): Promise<ForecastDay[]> {
  const apiKey = process.env.OPENWEATHERMAP_API_KEY;
  const cityConf = getCityConfig(city);
  if (!apiKey || !cityConf) return getMockForecast(city);

  const cached = await WeatherData.findOne({
    city, dataType: 'Weather',
    fetchedAt: { $gte: new Date(Date.now() - CACHE_TTL_FORECAST_MS) },
  });

  if (cached?.data?.description?.includes('forecast')) {
    return JSON.parse(cached.data.description.replace('forecast:', ''));
  }

  const raw = await owmFetch<any>(
    `${OWM_BASE}/forecast?q=${encodeURIComponent(cityConf.owmName)}&appid=${apiKey}&units=metric`
  );

  if (!raw?.list) return getMockForecast(city);

  // Group by day — take noon reading per day
  const byDay = new Map<string, any>();
  for (const item of raw.list as any[]) {
    const date = new Date(item.dt * 1000).toISOString().slice(0, 10);
    if (!byDay.has(date)) byDay.set(date, item);
  }

  return Array.from(byDay.entries()).slice(0, 5).map(([date, item]) => ({
    date,
    tempMin:  item.main.temp_min,
    tempMax:  item.main.temp_max,
    rainfall: (item.rain?.['3h'] ?? 0),
    weatherCondition: item.weather?.[0]?.main ?? 'Unknown',
    description:      item.weather?.[0]?.description ?? '',
    humidity:         item.main.humidity,
  }));
}

function getMockForecast(city: string): ForecastDay[] {
  const base = new Date();
  const conditions = ['Partly Cloudy', 'Sunny', 'Overcast', 'Clear', 'Hazy'];
  return Array.from({ length: 5 }, (_, i) => {
    const d = new Date(base);
    d.setDate(d.getDate() + i);
    return {
      date: d.toISOString().slice(0, 10),
      tempMin:  22 + Math.floor(Math.random() * 5),
      tempMax:  30 + Math.floor(Math.random() * 8),
      rainfall: i === 2 ? 45 : 0,
      weatherCondition: conditions[i % conditions.length],
      description: 'Forecast data (mock)',
      humidity: 55 + Math.floor(Math.random() * 20),
    };
  });
}

export { evaluateDisruptionSeverity };
