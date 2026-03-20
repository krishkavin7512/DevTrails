/**
 * RainCheck Database Seeder
 * Run: npx ts-node src/data/seedDatabase.ts
 *
 * Seeds all collections with the comprehensive mock dataset from seedData.ts.
 * Safe to re-run — drops existing data and reseeds.
 */

import mongoose from 'mongoose';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.resolve(__dirname, '../../.env') });

import Rider from '../models/Rider';
import Policy from '../models/Policy';
import Claim from '../models/Claim';
import WeatherData from '../models/WeatherData';
import DisruptionEvent from '../models/DisruptionEvent';
import { RIDERS, POLICIES, CLAIMS, DISRUPTION_EVENTS, CITY_RISK_PROFILES } from './seedData';

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/raincheck';

// ─── Sample current weather snapshot for all 10 cities ───────────────────────

const CURRENT_WEATHER_SNAPSHOTS = [
  {
    city: 'Mumbai', pincode: '400058', dataType: 'Weather' as const,
    data: { temperature: 32.4, feelsLike: 38.7, humidity: 84, rainfall: 81.7, windSpeed: 5.2, aqi: 95, pm25: 42, pm10: 78, weatherCondition: 'Heavy Rain', description: 'Torrential rain — IMD Red Alert active' },
    isDisruptionActive: true, disruptionSeverity: 'Severe' as const,
    fetchedAt: new Date(), source: 'OpenWeatherMap',
  },
  {
    city: 'Delhi', pincode: '110075', dataType: 'AQI' as const,
    data: { temperature: 22.1, feelsLike: 20.8, humidity: 62, rainfall: 0, windSpeed: 1.8, aqi: 462, pm25: 298, pm10: 415, weatherCondition: 'Haze', description: 'Severe AQI — GRAP Stage III active' },
    isDisruptionActive: true, disruptionSeverity: 'Severe' as const,
    fetchedAt: new Date(), source: 'CPCB + OpenWeatherMap',
  },
  {
    city: 'Bangalore', pincode: '560034', dataType: 'Weather' as const,
    data: { temperature: 26.8, feelsLike: 28.2, humidity: 70, rainfall: 0, windSpeed: 3.4, aqi: 68, pm25: 31, pm10: 52, weatherCondition: 'Partly Cloudy', description: 'Pleasant conditions — no disruption' },
    isDisruptionActive: false, disruptionSeverity: 'None' as const,
    fetchedAt: new Date(), source: 'OpenWeatherMap',
  },
  {
    city: 'Chennai', pincode: '600042', dataType: 'Weather' as const,
    data: { temperature: 34.5, feelsLike: 41.2, humidity: 78, rainfall: 4.2, windSpeed: 4.1, aqi: 110, pm25: 55, pm10: 88, weatherCondition: 'Humid', description: 'Hot and humid — no trigger active' },
    isDisruptionActive: false, disruptionSeverity: 'None' as const,
    fetchedAt: new Date(), source: 'OpenWeatherMap',
  },
  {
    city: 'Hyderabad', pincode: '500072', dataType: 'Weather' as const,
    data: { temperature: 38.9, feelsLike: 42.1, humidity: 55, rainfall: 0, windSpeed: 2.9, aqi: 128, pm25: 67, pm10: 102, weatherCondition: 'Sunny', description: 'Hot afternoon — feels-like approaching threshold' },
    isDisruptionActive: false, disruptionSeverity: 'Mild' as const,
    fetchedAt: new Date(), source: 'OpenWeatherMap',
  },
  {
    city: 'Kolkata', pincode: '700064', dataType: 'Weather' as const,
    data: { temperature: 29.3, feelsLike: 35.1, humidity: 80, rainfall: 12.3, windSpeed: 4.8, aqi: 145, pm25: 78, pm10: 115, weatherCondition: 'Light Rain', description: 'Pre-monsoon showers — monitoring for escalation' },
    isDisruptionActive: false, disruptionSeverity: 'None' as const,
    fetchedAt: new Date(), source: 'OpenWeatherMap',
  },
  {
    city: 'Pune', pincode: '411038', dataType: 'Weather' as const,
    data: { temperature: 28.7, feelsLike: 31.4, humidity: 65, rainfall: 2.1, windSpeed: 3.2, aqi: 82, pm25: 38, pm10: 61, weatherCondition: 'Overcast', description: 'Cloudy with light rain — no active trigger' },
    isDisruptionActive: false, disruptionSeverity: 'None' as const,
    fetchedAt: new Date(), source: 'OpenWeatherMap',
  },
  {
    city: 'Ahmedabad', pincode: '380009', dataType: 'Weather' as const,
    data: { temperature: 41.2, feelsLike: 43.8, humidity: 32, rainfall: 0, windSpeed: 5.5, aqi: 162, pm25: 88, pm10: 130, weatherCondition: 'Sunny', description: 'Hot day — summer conditions' },
    isDisruptionActive: false, disruptionSeverity: 'Mild' as const,
    fetchedAt: new Date(), source: 'OpenWeatherMap',
  },
  {
    city: 'Jaipur', pincode: '302021', dataType: 'Weather' as const,
    data: { temperature: 39.8, feelsLike: 41.5, humidity: 28, rainfall: 0, windSpeed: 7.1, aqi: 188, pm25: 98, pm10: 148, weatherCondition: 'Dusty', description: 'High heat and dust haze — monitoring AQI closely' },
    isDisruptionActive: false, disruptionSeverity: 'Mild' as const,
    fetchedAt: new Date(), source: 'OpenWeatherMap',
  },
  {
    city: 'Lucknow', pincode: '226001', dataType: 'AQI' as const,
    data: { temperature: 36.2, feelsLike: 38.9, humidity: 45, rainfall: 0, windSpeed: 2.1, aqi: 218, pm25: 138, pm10: 198, weatherCondition: 'Hazy', description: 'Moderately poor AQI — approaching alert threshold' },
    isDisruptionActive: false, disruptionSeverity: 'Moderate' as const,
    fetchedAt: new Date(), source: 'CPCB + OpenWeatherMap',
  },
];

// ─── Seed runner ─────────────────────────────────────────────────────────────

async function seed() {
  console.log('🌱 RainCheck Database Seeder\n');
  console.log(`📡 Connecting to MongoDB: ${MONGODB_URI}`);

  await mongoose.connect(MONGODB_URI);
  console.log('✅ Connected to MongoDB\n');

  // Drop existing data
  console.log('🗑️  Clearing existing collections...');
  await Promise.all([
    Rider.deleteMany({}),
    Policy.deleteMany({}),
    Claim.deleteMany({}),
    WeatherData.deleteMany({}),
    DisruptionEvent.deleteMany({}),
  ]);
  console.log('   ✓ All collections cleared\n');

  // Seed Riders
  console.log(`👤 Seeding ${RIDERS.length} riders...`);
  await Rider.insertMany(RIDERS);
  console.log(`   ✓ ${RIDERS.length} riders inserted`);

  // City breakdown
  const cityCounts = RIDERS.reduce<Record<string, number>>((acc, r) => {
    acc[r.city] = (acc[r.city] || 0) + 1;
    return acc;
  }, {});
  Object.entries(cityCounts).forEach(([city, count]) =>
    console.log(`     ${city}: ${count} riders`)
  );

  // Risk tier breakdown
  const tierCounts = RIDERS.reduce<Record<string, number>>((acc, r) => {
    acc[r.riskTier] = (acc[r.riskTier] || 0) + 1;
    return acc;
  }, {});
  console.log(`   Risk tiers: Low=${tierCounts.Low || 0} | Medium=${tierCounts.Medium || 0} | High=${tierCounts.High || 0} | VeryHigh=${tierCounts.VeryHigh || 0}\n`);

  // Seed Policies
  console.log(`📋 Seeding ${POLICIES.length} policies...`);
  await Policy.insertMany(POLICIES);
  const planCounts = POLICIES.reduce<Record<string, number>>((acc, p) => {
    acc[p.planType] = (acc[p.planType] || 0) + 1;
    return acc;
  }, {});
  const statusCounts = POLICIES.reduce<Record<string, number>>((acc, p) => {
    acc[p.status] = (acc[p.status] || 0) + 1;
    return acc;
  }, {});
  console.log(`   ✓ ${POLICIES.length} policies inserted`);
  console.log(`   Plans: Basic=${planCounts.Basic || 0} | Standard=${planCounts.Standard || 0} | Premium=${planCounts.Premium || 0}`);
  console.log(`   Status: Active=${statusCounts.Active || 0} | Expired=${statusCounts.Expired || 0} | Cancelled=${statusCounts.Cancelled || 0} | Pending=${statusCounts.PendingPayment || 0}\n`);

  // Seed Claims
  console.log(`📄 Seeding ${CLAIMS.length} claims...`);
  await Claim.insertMany(CLAIMS);
  const claimStatusCounts = CLAIMS.reduce<Record<string, number>>((acc, c) => {
    acc[c.status] = (acc[c.status] || 0) + 1;
    return acc;
  }, {});
  const totalPaidOut = CLAIMS
    .filter(c => c.status === 'Paid' || c.status === 'Approved')
    .reduce((sum, c) => sum + c.payoutAmount, 0);
  console.log(`   ✓ ${CLAIMS.length} claims inserted`);
  console.log(`   Paid=${claimStatusCounts.Paid || 0} | Approved=${claimStatusCounts.Approved || 0} | AutoInitiated=${claimStatusCounts.AutoInitiated || 0} | UnderReview=${claimStatusCounts.UnderReview || 0} | Rejected=${claimStatusCounts.Rejected || 0} | Fraud=${claimStatusCounts.FraudSuspected || 0}`);
  console.log(`   Total paid/approved: ₹${(totalPaidOut / 100).toLocaleString('en-IN')}\n`);

  // Seed DisruptionEvents
  console.log(`⚡ Seeding ${DISRUPTION_EVENTS.length} disruption events...`);
  await DisruptionEvent.insertMany(DISRUPTION_EVENTS);
  const activeEvents = DISRUPTION_EVENTS.filter(e => e.isActive).length;
  const totalAffected = DISRUPTION_EVENTS.reduce((sum, e) => sum + e.affectedRiders, 0);
  const totalHistoricalPayouts = DISRUPTION_EVENTS.reduce((sum, e) => sum + e.totalPayouts, 0);
  console.log(`   ✓ ${DISRUPTION_EVENTS.length} events inserted (${activeEvents} currently active)`);
  console.log(`   Total riders ever affected: ${totalAffected}`);
  console.log(`   Total historical payouts: ₹${(totalHistoricalPayouts / 100).toLocaleString('en-IN')}\n`);

  // Seed WeatherData (current snapshots)
  console.log(`🌦️  Seeding ${CURRENT_WEATHER_SNAPSHOTS.length} weather snapshots...`);
  await WeatherData.insertMany(CURRENT_WEATHER_SNAPSHOTS);
  const activeDisruptions = CURRENT_WEATHER_SNAPSHOTS.filter(w => w.isDisruptionActive).length;
  console.log(`   ✓ ${CURRENT_WEATHER_SNAPSHOTS.length} weather snapshots inserted`);
  console.log(`   Active disruptions right now: ${activeDisruptions} cities\n`);

  // Summary
  console.log('═'.repeat(60));
  console.log('✅ Database seeding complete!\n');
  console.log('📊 Summary:');
  console.log(`   Riders:             ${RIDERS.length}`);
  console.log(`   Policies:           ${POLICIES.length}`);
  console.log(`   Claims:             ${CLAIMS.length}`);
  console.log(`   Disruption Events:  ${DISRUPTION_EVENTS.length}`);
  console.log(`   Weather Snapshots:  ${CURRENT_WEATHER_SNAPSHOTS.length}`);
  console.log(`   Cities covered:     10`);
  console.log('');
  console.log('🏙️  City Risk Profiles (not stored in DB, used by ML service):');
  CITY_RISK_PROFILES.forEach(p =>
    console.log(`   ${p.city.padEnd(12)} | Risk: ${String(p.baseRiskScore).padStart(2)} | Multiplier: ${p.avgPremiumMultiplier}x | Top risk: ${p.topRisks[0]}`)
  );
  console.log('═'.repeat(60));

  await mongoose.disconnect();
  console.log('\n📡 Disconnected from MongoDB. Seeding complete! 🎉');
  process.exit(0);
}

seed().catch(err => {
  console.error('❌ Seeding failed:', err);
  mongoose.disconnect();
  process.exit(1);
});
