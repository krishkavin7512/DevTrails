import mongoose from 'mongoose';

// ─── Types ────────────────────────────────────────────────────────────────────

export interface SeedRider {
  _id: mongoose.Types.ObjectId;
  fullName: string;
  phone: string;
  email?: string;
  city: string;
  platform: 'Zomato' | 'Swiggy' | 'Both';
  operatingZone: string;
  operatingPincode: string;
  avgWeeklyEarnings: number;
  avgDailyHours: number;
  preferredShift: 'Morning' | 'Afternoon' | 'Evening' | 'Night' | 'Mixed';
  vehicleType: 'Bicycle' | 'Scooter' | 'Motorcycle';
  experienceMonths: number;
  riskTier: 'Low' | 'Medium' | 'High' | 'VeryHigh';
  riskScore: number;
  isActive: boolean;
  kycVerified: boolean;
  registeredAt: Date;
  lastActiveAt: Date;
  location: { lat: number; lng: number };
}

export interface SeedPolicy {
  _id: mongoose.Types.ObjectId;
  riderId: mongoose.Types.ObjectId;
  planType: 'Basic' | 'Standard' | 'Premium';
  weeklyPremium: number;
  coverageLimit: number;
  coveredDisruptions: string[];
  status: 'Active' | 'Expired' | 'Cancelled' | 'PendingPayment';
  startDate: Date;
  endDate: Date;
  autoRenew: boolean;
  policyNumber: string;
  renewalCount: number;
}

export interface SeedClaim {
  _id: mongoose.Types.ObjectId;
  policyId: mongoose.Types.ObjectId;
  riderId: mongoose.Types.ObjectId;
  claimNumber: string;
  triggerType: 'HeavyRain' | 'ExtremeHeat' | 'SevereAQI' | 'Flooding' | 'SocialDisruption';
  triggerData: {
    parameter: string;
    threshold: number;
    actualValue: number;
    dataSource: string;
    timestamp: Date;
    location: { lat: number; lng: number };
  };
  estimatedLostHours: number;
  payoutAmount: number;
  status: 'AutoInitiated' | 'UnderReview' | 'Approved' | 'Paid' | 'Rejected' | 'FraudSuspected';
  fraudScore: number;
  fraudFlags: string[];
  processedAt?: Date;
  paidAt?: Date;
}

export interface SeedDisruptionEvent {
  _id: mongoose.Types.ObjectId;
  city: string;
  zones: string[];
  type: 'HeavyRain' | 'ExtremeHeat' | 'SevereAQI' | 'Flooding' | 'SocialDisruption';
  severity: 'Moderate' | 'Severe' | 'Extreme';
  title: string;
  description: string;
  startTime: Date;
  endTime?: Date;
  triggerData: { parameter: string; value: number; threshold: number };
  affectedRiders: number;
  totalPayouts: number;
  claimsGenerated: number;
  isActive: boolean;
  source: 'Automated' | 'AdminTriggered' | 'CommunityReport';
}

export interface CityRiskProfile {
  city: string;
  baseRiskScore: number;
  topRisks: string[];
  avgDisruptionsPerMonth: number;
  worstMonths: string[];
  avgPremiumMultiplier: number;
  floodProneZones: string[];
  historicalAvgRainfall: { monsoon: number; winter: number; summer: number };
  avgAQI: { winter: number; summer: number; monsoon: number };
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

const id = () => new mongoose.Types.ObjectId();
const daysAgo = (n: number) => new Date(Date.now() - n * 86_400_000);
const hoursAgo = (n: number) => new Date(Date.now() - n * 3_600_000);
const paise = (rupees: number) => rupees * 100;

// ─── RIDERS (50 riders across 10 cities) ─────────────────────────────────────

const r = (overrides: Partial<SeedRider> & Pick<SeedRider, 'fullName' | 'phone' | 'city' | 'platform' | 'operatingZone' | 'operatingPincode' | 'avgWeeklyEarnings' | 'avgDailyHours' | 'preferredShift' | 'vehicleType' | 'experienceMonths' | 'riskTier' | 'riskScore' | 'location'>): SeedRider => ({
  _id: id(),
  email: undefined,
  isActive: true,
  kycVerified: true,
  registeredAt: daysAgo(Math.floor(Math.random() * 300 + 30)),
  lastActiveAt: daysAgo(Math.floor(Math.random() * 3)),
  ...overrides,
});

export const RIDERS: SeedRider[] = [
  // ── Mumbai (9 riders) ──────────────────────────────────────────────────────
  r({ fullName: 'Rajesh Kumar Yadav',    phone: '9876543210', city: 'Mumbai',    platform: 'Zomato',  operatingZone: 'Andheri West',  operatingPincode: '400058', avgWeeklyEarnings: paise(4200), avgDailyHours: 10, preferredShift: 'Mixed',     vehicleType: 'Scooter',     experienceMonths: 28, riskTier: 'Medium',   riskScore: 52, location: { lat: 19.1357, lng: 72.8264 }, kycVerified: true  }),
  r({ fullName: 'Santosh Dnyaneshwar Patil', phone: '9823456781', city: 'Mumbai', platform: 'Swiggy', operatingZone: 'Borivali East', operatingPincode: '400066', avgWeeklyEarnings: paise(3600), avgDailyHours: 9,  preferredShift: 'Afternoon', vehicleType: 'Scooter',     experienceMonths: 14, riskTier: 'High',     riskScore: 68, location: { lat: 19.2288, lng: 72.8574 }, kycVerified: true  }),
  r({ fullName: 'Vikram Anil Shinde',    phone: '9867001234', city: 'Mumbai',    platform: 'Both',    operatingZone: 'Dadar West',    operatingPincode: '400028', avgWeeklyEarnings: paise(5100), avgDailyHours: 12, preferredShift: 'Evening',   vehicleType: 'Motorcycle',  experienceMonths: 41, riskTier: 'Medium',   riskScore: 48, location: { lat: 19.0177, lng: 72.8428 }, kycVerified: true  }),
  r({ fullName: 'Mohammed Imran Shaikh', phone: '9712345678', city: 'Mumbai',    platform: 'Zomato',  operatingZone: 'Kurla West',    operatingPincode: '400070', avgWeeklyEarnings: paise(3900), avgDailyHours: 11, preferredShift: 'Night',     vehicleType: 'Scooter',     experienceMonths: 7,  riskTier: 'High',     riskScore: 73, location: { lat: 19.0728, lng: 72.8826 }, kycVerified: false }),
  r({ fullName: 'Ganesh Ramchandra Naik',phone: '9845678902', city: 'Mumbai',    platform: 'Swiggy',  operatingZone: 'Chembur',       operatingPincode: '400071', avgWeeklyEarnings: paise(4600), avgDailyHours: 10, preferredShift: 'Morning',   vehicleType: 'Motorcycle',  experienceMonths: 33, riskTier: 'Medium',   riskScore: 55, location: { lat: 19.0626, lng: 72.9010 }, kycVerified: true  }),
  r({ fullName: 'Akash Suresh Gaikwad',  phone: '9634567890', city: 'Mumbai',    platform: 'Zomato',  operatingZone: 'Sion',          operatingPincode: '400022', avgWeeklyEarnings: paise(2900), avgDailyHours: 7,  preferredShift: 'Afternoon', vehicleType: 'Bicycle',     experienceMonths: 4,  riskTier: 'High',     riskScore: 71, location: { lat: 19.0388, lng: 72.8617 }, kycVerified: true  }),
  r({ fullName: 'Prashant Dilip More',   phone: '9523456789', city: 'Mumbai',    platform: 'Both',    operatingZone: 'Malad West',    operatingPincode: '400064', avgWeeklyEarnings: paise(5400), avgDailyHours: 13, preferredShift: 'Mixed',     vehicleType: 'Motorcycle',  experienceMonths: 55, riskTier: 'Low',      riskScore: 31, location: { lat: 19.1871, lng: 72.8486 }, kycVerified: true  }),
  r({ fullName: 'Rohit Chandrakant Desai',phone:'9412345670', city: 'Mumbai',    platform: 'Swiggy',  operatingZone: 'Vile Parle',    operatingPincode: '400057', avgWeeklyEarnings: paise(4100), avgDailyHours: 9,  preferredShift: 'Evening',   vehicleType: 'Scooter',     experienceMonths: 22, riskTier: 'Medium',   riskScore: 50, location: { lat: 19.1075, lng: 72.8449 }, kycVerified: true  }),
  r({ fullName: 'Nilesh Pravin Kamble',  phone: '9301234567', city: 'Mumbai',    platform: 'Zomato',  operatingZone: 'Thane West',    operatingPincode: '400601', avgWeeklyEarnings: paise(3300), avgDailyHours: 8,  preferredShift: 'Morning',   vehicleType: 'Scooter',     experienceMonths: 11, riskTier: 'High',     riskScore: 65, location: { lat: 19.2183, lng: 72.9781 }, kycVerified: false }),

  // ── Delhi (8 riders) ───────────────────────────────────────────────────────
  r({ fullName: 'Priya Sharma',          phone: '9810234567', city: 'Delhi',     platform: 'Swiggy',  operatingZone: 'Dwarka Sector 6', operatingPincode: '110075', avgWeeklyEarnings: paise(3800), avgDailyHours: 8,  preferredShift: 'Afternoon', vehicleType: 'Scooter',     experienceMonths: 19, riskTier: 'VeryHigh', riskScore: 88, location: { lat: 28.5823, lng: 77.0500 }, kycVerified: true  }),
  r({ fullName: 'Arvind Singh Chauhan',  phone: '9711345678', city: 'Delhi',     platform: 'Zomato',  operatingZone: 'Rohini Sector 11',operatingPincode: '110085', avgWeeklyEarnings: paise(4400), avgDailyHours: 11, preferredShift: 'Night',     vehicleType: 'Motorcycle',  experienceMonths: 36, riskTier: 'VeryHigh', riskScore: 84, location: { lat: 28.7495, lng: 77.0700 }, kycVerified: true  }),
  r({ fullName: 'Deepak Raj Gupta',      phone: '9612345670', city: 'Delhi',     platform: 'Both',    operatingZone: 'Lajpat Nagar',  operatingPincode: '110024', avgWeeklyEarnings: paise(5200), avgDailyHours: 12, preferredShift: 'Evening',   vehicleType: 'Motorcycle',  experienceMonths: 48, riskTier: 'High',     riskScore: 76, location: { lat: 28.5677, lng: 77.2434 }, kycVerified: true  }),
  r({ fullName: 'Sanjay Kumar Pandey',   phone: '9512356789', city: 'Delhi',     platform: 'Swiggy',  operatingZone: 'Janakpuri',     operatingPincode: '110058', avgWeeklyEarnings: paise(3100), avgDailyHours: 8,  preferredShift: 'Morning',   vehicleType: 'Scooter',     experienceMonths: 9,  riskTier: 'VeryHigh', riskScore: 91, location: { lat: 28.6219, lng: 77.0878 }, kycVerified: false }),
  r({ fullName: 'Arun Dev Mishra',       phone: '9412567890', city: 'Delhi',     platform: 'Zomato',  operatingZone: 'Saket',         operatingPincode: '110017', avgWeeklyEarnings: paise(4700), avgDailyHours: 10, preferredShift: 'Mixed',     vehicleType: 'Motorcycle',  experienceMonths: 27, riskTier: 'High',     riskScore: 79, location: { lat: 28.5244, lng: 77.2066 }, kycVerified: true  }),
  r({ fullName: 'Ravi Shankar Verma',    phone: '9313456789', city: 'Delhi',     platform: 'Both',    operatingZone: 'Karol Bagh',    operatingPincode: '110005', avgWeeklyEarnings: paise(4000), avgDailyHours: 9,  preferredShift: 'Afternoon', vehicleType: 'Scooter',     experienceMonths: 15, riskTier: 'VeryHigh', riskScore: 86, location: { lat: 28.6520, lng: 77.1902 }, kycVerified: true  }),
  r({ fullName: 'Mohit Pal Singh',       phone: '9214567890', city: 'Delhi',     platform: 'Swiggy',  operatingZone: 'Pitampura',     operatingPincode: '110034', avgWeeklyEarnings: paise(2800), avgDailyHours: 7,  preferredShift: 'Morning',   vehicleType: 'Bicycle',     experienceMonths: 3,  riskTier: 'VeryHigh', riskScore: 89, location: { lat: 28.7017, lng: 77.1311 }, kycVerified: false }),
  r({ fullName: 'Harish Dutta',          phone: '9115678901', city: 'Delhi',     platform: 'Zomato',  operatingZone: 'Greater Kailash', operatingPincode: '110048', avgWeeklyEarnings: paise(5800), avgDailyHours: 13, preferredShift: 'Night',    vehicleType: 'Motorcycle',  experienceMonths: 52, riskTier: 'High',     riskScore: 74, location: { lat: 28.5490, lng: 77.2359 }, kycVerified: true  }),

  // ── Bangalore (7 riders) ───────────────────────────────────────────────────
  r({ fullName: 'Suresh Babu Naidu',     phone: '9980123456', city: 'Bangalore', platform: 'Swiggy',  operatingZone: 'Koramangala',   operatingPincode: '560034', avgWeeklyEarnings: paise(2800), avgDailyHours: 7,  preferredShift: 'Afternoon', vehicleType: 'Bicycle',     experienceMonths: 6,  riskTier: 'Low',      riskScore: 29, location: { lat: 12.9352, lng: 77.6245 }, kycVerified: true  }),
  r({ fullName: 'Kiran Gowda',           phone: '9881234567', city: 'Bangalore', platform: 'Zomato',  operatingZone: 'Indiranagar',   operatingPincode: '560038', avgWeeklyEarnings: paise(3700), avgDailyHours: 9,  preferredShift: 'Evening',   vehicleType: 'Scooter',     experienceMonths: 21, riskTier: 'Low',      riskScore: 34, location: { lat: 12.9784, lng: 77.6408 }, kycVerified: true  }),
  r({ fullName: 'Manjunath Reddy',       phone: '9782345678', city: 'Bangalore', platform: 'Both',    operatingZone: 'Whitefield',    operatingPincode: '560066', avgWeeklyEarnings: paise(4300), avgDailyHours: 10, preferredShift: 'Mixed',     vehicleType: 'Motorcycle',  experienceMonths: 38, riskTier: 'Medium',   riskScore: 43, location: { lat: 12.9698, lng: 77.7499 }, kycVerified: true  }),
  r({ fullName: 'Basavaraj Lingappa',    phone: '9683456789', city: 'Bangalore', platform: 'Swiggy',  operatingZone: 'Jayanagar',     operatingPincode: '560041', avgWeeklyEarnings: paise(3200), avgDailyHours: 8,  preferredShift: 'Morning',   vehicleType: 'Scooter',     experienceMonths: 13, riskTier: 'Low',      riskScore: 27, location: { lat: 12.9299, lng: 77.5826 }, kycVerified: true  }),
  r({ fullName: 'Venkatesh S Rao',       phone: '9584567890', city: 'Bangalore', platform: 'Zomato',  operatingZone: 'Marathahalli',  operatingPincode: '560037', avgWeeklyEarnings: paise(4800), avgDailyHours: 11, preferredShift: 'Night',     vehicleType: 'Motorcycle',  experienceMonths: 44, riskTier: 'Medium',   riskScore: 46, location: { lat: 12.9591, lng: 77.6972 }, kycVerified: true  }),
  r({ fullName: 'Raju Thimmaiah',        phone: '9485678901', city: 'Bangalore', platform: 'Both',    operatingZone: 'Electronic City',operatingPincode: '560100', avgWeeklyEarnings: paise(3500), avgDailyHours: 9,  preferredShift: 'Afternoon', vehicleType: 'Scooter',     experienceMonths: 17, riskTier: 'Low',      riskScore: 32, location: { lat: 12.8445, lng: 77.6603 }, kycVerified: false }),
  r({ fullName: 'Anand Kumar Hegde',     phone: '9386789012', city: 'Bangalore', platform: 'Swiggy',  operatingZone: 'HSR Layout',    operatingPincode: '560102', avgWeeklyEarnings: paise(2600), avgDailyHours: 6,  preferredShift: 'Morning',   vehicleType: 'Bicycle',     experienceMonths: 5,  riskTier: 'Low',      riskScore: 25, location: { lat: 12.9116, lng: 77.6370 }, kycVerified: true  }),

  // ── Chennai (6 riders) ─────────────────────────────────────────────────────
  r({ fullName: 'Karthik Subramanian',   phone: '9444123456', city: 'Chennai',   platform: 'Zomato',  operatingZone: 'Velachery',     operatingPincode: '600042', avgWeeklyEarnings: paise(3500), avgDailyHours: 9,  preferredShift: 'Mixed',     vehicleType: 'Motorcycle',  experienceMonths: 24, riskTier: 'High',     riskScore: 70, location: { lat: 12.9816, lng: 80.2207 }, kycVerified: true  }),
  r({ fullName: 'Murugan Palaniswamy',   phone: '9345234567', city: 'Chennai',   platform: 'Swiggy',  operatingZone: 'T. Nagar',      operatingPincode: '600017', avgWeeklyEarnings: paise(4100), avgDailyHours: 10, preferredShift: 'Evening',   vehicleType: 'Scooter',     experienceMonths: 31, riskTier: 'Medium',   riskScore: 57, location: { lat: 13.0418, lng: 80.2341 }, kycVerified: true  }),
  r({ fullName: 'Selvam Arumugam',       phone: '9246345678', city: 'Chennai',   platform: 'Both',    operatingZone: 'Adyar',         operatingPincode: '600020', avgWeeklyEarnings: paise(3800), avgDailyHours: 9,  preferredShift: 'Afternoon', vehicleType: 'Motorcycle',  experienceMonths: 18, riskTier: 'High',     riskScore: 67, location: { lat: 13.0012, lng: 80.2565 }, kycVerified: true  }),
  r({ fullName: 'Dinesh Raj T.',         phone: '9147456789', city: 'Chennai',   platform: 'Zomato',  operatingZone: 'Anna Nagar',    operatingPincode: '600040', avgWeeklyEarnings: paise(4600), avgDailyHours: 11, preferredShift: 'Night',     vehicleType: 'Motorcycle',  experienceMonths: 42, riskTier: 'Medium',   riskScore: 54, location: { lat: 13.0850, lng: 80.2101 }, kycVerified: true  }),
  r({ fullName: 'Senthil Kumar V.',      phone: '9048567890', city: 'Chennai',   platform: 'Swiggy',  operatingZone: 'Tambaram',      operatingPincode: '600045', avgWeeklyEarnings: paise(2700), avgDailyHours: 7,  preferredShift: 'Morning',   vehicleType: 'Bicycle',     experienceMonths: 5,  riskTier: 'High',     riskScore: 72, location: { lat: 12.9249, lng: 80.1000 }, kycVerified: false }),
  r({ fullName: 'Govindarajan Pillai',   phone: '9949678901', city: 'Chennai',   platform: 'Zomato',  operatingZone: 'Porur',         operatingPincode: '600116', avgWeeklyEarnings: paise(3300), avgDailyHours: 8,  preferredShift: 'Afternoon', vehicleType: 'Scooter',     experienceMonths: 12, riskTier: 'High',     riskScore: 69, location: { lat: 13.0343, lng: 80.1564 }, kycVerified: true  }),

  // ── Hyderabad (5 riders) ───────────────────────────────────────────────────
  r({ fullName: 'Md. Faizan Ahmed',      phone: '9550123456', city: 'Hyderabad', platform: 'Both',    operatingZone: 'Kukatpally',    operatingPincode: '500072', avgWeeklyEarnings: paise(4500), avgDailyHours: 11, preferredShift: 'Mixed',     vehicleType: 'Scooter',     experienceMonths: 26, riskTier: 'Medium',   riskScore: 51, location: { lat: 17.4849, lng: 78.4138 }, kycVerified: true  }),
  r({ fullName: 'Venkat Rao Bojja',      phone: '9451234567', city: 'Hyderabad', platform: 'Zomato',  operatingZone: 'Madhapur',      operatingPincode: '500081', avgWeeklyEarnings: paise(5300), avgDailyHours: 12, preferredShift: 'Evening',   vehicleType: 'Motorcycle',  experienceMonths: 47, riskTier: 'Medium',   riskScore: 49, location: { lat: 17.4474, lng: 78.3762 }, kycVerified: true  }),
  r({ fullName: 'Ravi Teja Namburi',     phone: '9352345678', city: 'Hyderabad', platform: 'Swiggy',  operatingZone: 'LB Nagar',      operatingPincode: '500074', avgWeeklyEarnings: paise(3400), avgDailyHours: 8,  preferredShift: 'Afternoon', vehicleType: 'Scooter',     experienceMonths: 16, riskTier: 'High',     riskScore: 63, location: { lat: 17.3616, lng: 78.5528 }, kycVerified: false }),
  r({ fullName: 'Sai Krishna Reddy',     phone: '9253456789', city: 'Hyderabad', platform: 'Zomato',  operatingZone: 'Gachibowli',    operatingPincode: '500032', avgWeeklyEarnings: paise(4900), avgDailyHours: 11, preferredShift: 'Night',     vehicleType: 'Motorcycle',  experienceMonths: 35, riskTier: 'Medium',   riskScore: 47, location: { lat: 17.4401, lng: 78.3489 }, kycVerified: true  }),
  r({ fullName: 'Ramesh Chandra Yadav',  phone: '9154567890', city: 'Hyderabad', platform: 'Both',    operatingZone: 'Secunderabad',  operatingPincode: '500003', avgWeeklyEarnings: paise(3700), avgDailyHours: 9,  preferredShift: 'Morning',   vehicleType: 'Scooter',     experienceMonths: 20, riskTier: 'Medium',   riskScore: 53, location: { lat: 17.4399, lng: 78.4983 }, kycVerified: true  }),

  // ── Kolkata (5 riders) ─────────────────────────────────────────────────────
  r({ fullName: 'Subhash Chandra Ghosh', phone: '9830123456', city: 'Kolkata',   platform: 'Swiggy',  operatingZone: 'Salt Lake',     operatingPincode: '700064', avgWeeklyEarnings: paise(3200), avgDailyHours: 8,  preferredShift: 'Afternoon', vehicleType: 'Scooter',     experienceMonths: 23, riskTier: 'High',     riskScore: 66, location: { lat: 22.5726, lng: 88.3639 }, kycVerified: true  }),
  r({ fullName: 'Prosenjit Banerjee',    phone: '9731234567', city: 'Kolkata',   platform: 'Zomato',  operatingZone: 'Park Street',   operatingPincode: '700016', avgWeeklyEarnings: paise(4200), avgDailyHours: 10, preferredShift: 'Night',     vehicleType: 'Motorcycle',  experienceMonths: 32, riskTier: 'Medium',   riskScore: 58, location: { lat: 22.5509, lng: 88.3519 }, kycVerified: true  }),
  r({ fullName: 'Amit Kr. Das',          phone: '9632345678', city: 'Kolkata',   platform: 'Both',    operatingZone: 'Howrah',        operatingPincode: '711101', avgWeeklyEarnings: paise(2900), avgDailyHours: 7,  preferredShift: 'Morning',   vehicleType: 'Bicycle',     experienceMonths: 8,  riskTier: 'High',     riskScore: 71, location: { lat: 22.5958, lng: 88.2636 }, kycVerified: false }),
  r({ fullName: 'Raktim Bhattacharya',   phone: '9533456789', city: 'Kolkata',   platform: 'Swiggy',  operatingZone: 'Ballygunge',    operatingPincode: '700019', avgWeeklyEarnings: paise(3600), avgDailyHours: 9,  preferredShift: 'Evening',   vehicleType: 'Scooter',     experienceMonths: 18, riskTier: 'Medium',   riskScore: 60, location: { lat: 22.5245, lng: 88.3675 }, kycVerified: true  }),
  r({ fullName: 'Sourav Mondal',         phone: '9434567890', city: 'Kolkata',   platform: 'Zomato',  operatingZone: 'New Town',      operatingPincode: '700156', avgWeeklyEarnings: paise(4100), avgDailyHours: 10, preferredShift: 'Mixed',     vehicleType: 'Motorcycle',  experienceMonths: 29, riskTier: 'High',     riskScore: 64, location: { lat: 22.6069, lng: 88.4517 }, kycVerified: true  }),

  // ── Pune (4 riders) ────────────────────────────────────────────────────────
  r({ fullName: 'Manoj Baburao Jadhav',  phone: '9890123456', city: 'Pune',      platform: 'Zomato',  operatingZone: 'Kothrud',       operatingPincode: '411038', avgWeeklyEarnings: paise(3800), avgDailyHours: 9,  preferredShift: 'Afternoon', vehicleType: 'Scooter',     experienceMonths: 22, riskTier: 'Medium',   riskScore: 49, location: { lat: 18.5074, lng: 73.8077 }, kycVerified: true  }),
  r({ fullName: 'Yogesh Vilas Kulkarni', phone: '9791234567', city: 'Pune',      platform: 'Swiggy',  operatingZone: 'Hinjawadi',     operatingPincode: '411057', avgWeeklyEarnings: paise(4500), avgDailyHours: 11, preferredShift: 'Mixed',     vehicleType: 'Motorcycle',  experienceMonths: 37, riskTier: 'Low',      riskScore: 36, location: { lat: 18.5912, lng: 73.7389 }, kycVerified: true  }),
  r({ fullName: 'Abhijit Narayan Joshi', phone: '9692345678', city: 'Pune',      platform: 'Both',    operatingZone: 'Shivajinagar',  operatingPincode: '411005', avgWeeklyEarnings: paise(3100), avgDailyHours: 8,  preferredShift: 'Evening',   vehicleType: 'Scooter',     experienceMonths: 11, riskTier: 'Medium',   riskScore: 52, location: { lat: 18.5308, lng: 73.8474 }, kycVerified: false }),
  r({ fullName: 'Tushar Hemant Kale',    phone: '9593456789', city: 'Pune',      platform: 'Zomato',  operatingZone: 'Viman Nagar',   operatingPincode: '411014', avgWeeklyEarnings: paise(5100), avgDailyHours: 12, preferredShift: 'Night',     vehicleType: 'Motorcycle',  experienceMonths: 45, riskTier: 'Low',      riskScore: 33, location: { lat: 18.5679, lng: 73.9143 }, kycVerified: true  }),

  // ── Ahmedabad (3 riders) ───────────────────────────────────────────────────
  r({ fullName: 'Dhruv Manubhai Patel',  phone: '9925123456', city: 'Ahmedabad', platform: 'Swiggy',  operatingZone: 'Navrangpura',   operatingPincode: '380009', avgWeeklyEarnings: paise(3400), avgDailyHours: 9,  preferredShift: 'Afternoon', vehicleType: 'Scooter',     experienceMonths: 16, riskTier: 'Medium',   riskScore: 55, location: { lat: 23.0325, lng: 72.5714 }, kycVerified: true  }),
  r({ fullName: 'Jignesh Rakeshbhai Shah',phone:'9826234567', city: 'Ahmedabad', platform: 'Zomato',  operatingZone: 'Bopal',         operatingPincode: '380058', avgWeeklyEarnings: paise(4200), avgDailyHours: 10, preferredShift: 'Mixed',     vehicleType: 'Motorcycle',  experienceMonths: 29, riskTier: 'Medium',   riskScore: 50, location: { lat: 23.0285, lng: 72.4726 }, kycVerified: true  }),
  r({ fullName: 'Nilesh Amrutlal Modi',  phone: '9727345678', city: 'Ahmedabad', platform: 'Both',    operatingZone: 'Satellite',     operatingPincode: '380015', avgWeeklyEarnings: paise(3700), avgDailyHours: 9,  preferredShift: 'Evening',   vehicleType: 'Scooter',     experienceMonths: 20, riskTier: 'Low',      riskScore: 38, location: { lat: 23.0228, lng: 72.5259 }, kycVerified: false }),

  // ── Jaipur (3 riders) ─────────────────────────────────────────────────────
  r({ fullName: 'Rajendra Pratap Singh', phone: '9414123456', city: 'Jaipur',    platform: 'Zomato',  operatingZone: 'Vaishali Nagar', operatingPincode: '302021', avgWeeklyEarnings: paise(3600), avgDailyHours: 9,  preferredShift: 'Afternoon', vehicleType: 'Motorcycle',  experienceMonths: 25, riskTier: 'High',     riskScore: 73, location: { lat: 26.9124, lng: 75.7873 }, kycVerified: true  }),
  r({ fullName: 'Ankit Sharma Jaipur',   phone: '9315234567', city: 'Jaipur',    platform: 'Swiggy',  operatingZone: 'Malviya Nagar', operatingPincode: '302017', avgWeeklyEarnings: paise(4000), avgDailyHours: 10, preferredShift: 'Mixed',     vehicleType: 'Scooter',     experienceMonths: 18, riskTier: 'High',     riskScore: 69, location: { lat: 26.8580, lng: 75.8150 }, kycVerified: true  }),
  r({ fullName: 'Lokesh Choudhary',      phone: '9216345678', city: 'Jaipur',    platform: 'Both',    operatingZone: 'C-Scheme',      operatingPincode: '302001', avgWeeklyEarnings: paise(3200), avgDailyHours: 8,  preferredShift: 'Evening',   vehicleType: 'Scooter',     experienceMonths: 12, riskTier: 'High',     riskScore: 72, location: { lat: 26.9124, lng: 75.8049 }, kycVerified: false }),

  // ── Lucknow (3 riders) ─────────────────────────────────────────────────────
  r({ fullName: 'Shivam Awasthi',        phone: '9415123456', city: 'Lucknow',   platform: 'Swiggy',  operatingZone: 'Hazratganj',    operatingPincode: '226001', avgWeeklyEarnings: paise(3100), avgDailyHours: 8,  preferredShift: 'Afternoon', vehicleType: 'Scooter',     experienceMonths: 14, riskTier: 'High',     riskScore: 68, location: { lat: 26.8467, lng: 80.9462 }, kycVerified: true  }),
  r({ fullName: 'Pankaj Kumar Tiwari',   phone: '9316234567', city: 'Lucknow',   platform: 'Zomato',  operatingZone: 'Gomti Nagar',   operatingPincode: '226010', avgWeeklyEarnings: paise(4200), avgDailyHours: 10, preferredShift: 'Night',     vehicleType: 'Motorcycle',  experienceMonths: 31, riskTier: 'Medium',   riskScore: 57, location: { lat: 26.8599, lng: 81.0014 }, kycVerified: true  }),
  r({ fullName: 'Vivek Narayan Tripathi',phone: '9217345678', city: 'Lucknow',   platform: 'Both',    operatingZone: 'Aliganj',       operatingPincode: '226024', avgWeeklyEarnings: paise(3500), avgDailyHours: 9,  preferredShift: 'Mixed',     vehicleType: 'Scooter',     experienceMonths: 20, riskTier: 'High',     riskScore: 65, location: { lat: 26.8845, lng: 80.9398 }, kycVerified: false }),
];

// ─── POLICIES (40 policies) ───────────────────────────────────────────────────

const PLAN_CONFIG = {
  Basic:    { disruptions: ['HeavyRain', 'ExtremeHeat'],                                              coverageLimit: paise(800) },
  Standard: { disruptions: ['HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding'],                     coverageLimit: paise(1200) },
  Premium:  { disruptions: ['HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding', 'SocialDisruption'], coverageLimit: paise(1800) },
};

// City premium multipliers (in basis points added to base)
const CITY_MULTIPLIER: Record<string, number> = {
  Delhi: 1.45, Mumbai: 1.35, Chennai: 1.20, Kolkata: 1.25,
  Jaipur: 1.15, Lucknow: 1.15, Hyderabad: 1.10, Pune: 1.05,
  Ahmedabad: 1.00, Bangalore: 0.90,
};

const BASE_PREMIUM = { Basic: paise(32), Standard: paise(52), Premium: paise(72) };

function calcPremium(city: string, plan: 'Basic' | 'Standard' | 'Premium', expMonths: number, claimCount: number): number {
  const base = BASE_PREMIUM[plan];
  const cityMult = CITY_MULTIPLIER[city] ?? 1.0;
  const expDiscount = expMonths > 24 ? 0.90 : expMonths > 12 ? 0.95 : 1.0;
  const claimAdj = 1 + claimCount * 0.05;
  return Math.round(base * cityMult * expDiscount * claimAdj / 100) * 100;
}

function policyNumber(date: Date, seq: number): string {
  const d = date.toISOString().slice(0, 10).replace(/-/g, '');
  return `RC-${d}-${String(seq).padStart(5, '0')}`;
}

const policyStartDates = [
  daysAgo(3), daysAgo(5), daysAgo(1), daysAgo(7), daysAgo(2),
  daysAgo(6), daysAgo(4), daysAgo(0), daysAgo(3), daysAgo(5),
  daysAgo(14), daysAgo(14), daysAgo(21), daysAgo(21), daysAgo(28),
  daysAgo(28), daysAgo(35), daysAgo(35), daysAgo(42), daysAgo(42),
  daysAgo(1), daysAgo(2), daysAgo(3), daysAgo(4), daysAgo(5),
  daysAgo(6), daysAgo(7), daysAgo(8), daysAgo(9), daysAgo(10),
  daysAgo(11), daysAgo(12), daysAgo(13), daysAgo(15), daysAgo(16),
  daysAgo(17), daysAgo(18), daysAgo(19), daysAgo(20), daysAgo(22),
];

const policyPlans: Array<'Basic' | 'Standard' | 'Premium'> = [
  'Premium', 'Standard', 'Premium', 'Basic',    'Standard',
  'Premium', 'Standard', 'Basic',   'Premium',  'Standard',
  'Basic',   'Premium',  'Standard','Basic',    'Premium',
  'Standard','Basic',    'Premium', 'Standard', 'Basic',
  'Premium', 'Standard', 'Premium', 'Basic',    'Standard',
  'Premium', 'Basic',    'Standard','Premium',  'Standard',
  'Basic',   'Premium',  'Standard','Basic',    'Premium',
  'Standard','Premium',  'Basic',   'Standard', 'Premium',
];

const policyStatuses: Array<'Active' | 'Expired' | 'Cancelled' | 'PendingPayment'> = [
  'Active','Active','Active','Active','Active',
  'Active','Active','Active','Active','Active',
  'Active','Active','Active','Active','Active',
  'Active','Active','Active','Active','Active',
  'Active','Active','Active','Active','Active',
  'Active','Active','Active','Active','Expired',
  'Expired','Expired','Expired','Cancelled','Cancelled',
  'PendingPayment','PendingPayment','PendingPayment','Active','Active',
];

export const POLICIES: SeedPolicy[] = RIDERS.slice(0, 40).map((rider, i) => {
  const plan = policyPlans[i];
  const start = policyStartDates[i];
  const end = new Date(start.getTime() + 7 * 86_400_000);
  const premium = calcPremium(rider.city, plan, rider.experienceMonths, 0);
  return {
    _id: id(),
    riderId: rider._id,
    planType: plan,
    weeklyPremium: premium,
    coverageLimit: PLAN_CONFIG[plan].coverageLimit,
    coveredDisruptions: PLAN_CONFIG[plan].disruptions,
    status: policyStatuses[i],
    startDate: start,
    endDate: end,
    autoRenew: i % 5 !== 0,
    policyNumber: policyNumber(start, i + 1),
    renewalCount: Math.floor(i / 10),
  };
});

// ─── CLAIMS (30 claims) ───────────────────────────────────────────────────────

function claimNumber(date: Date, seq: number): string {
  const d = date.toISOString().slice(0, 10).replace(/-/g, '');
  return `CLM-${d}-${String(seq).padStart(5, '0')}`;
}

export const CLAIMS: SeedClaim[] = [
  // ── 18 PAID / APPROVED ───────────────────────────────────────────────────
  {
    _id: id(), policyId: POLICIES[0]._id, riderId: RIDERS[0]._id,
    claimNumber: claimNumber(daysAgo(51), 1),
    triggerType: 'HeavyRain',
    triggerData: {
      parameter: 'Rainfall intensity (mm/hr)', threshold: 64, actualValue: 78.3,
      dataSource: 'OpenWeatherMap + IMD Station ANX-07',
      timestamp: new Date('2025-07-18T14:30:00+05:30'),
      location: { lat: 19.1357, lng: 72.8264 },
    },
    estimatedLostHours: 4.5, payoutAmount: paise(900), status: 'Paid',
    fraudScore: 4, fraudFlags: [],
    processedAt: new Date('2025-07-18T17:00:00+05:30'),
    paidAt: new Date('2025-07-18T17:45:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[1]._id, riderId: RIDERS[1]._id,
    claimNumber: claimNumber(daysAgo(48), 2),
    triggerType: 'Flooding',
    triggerData: {
      parameter: 'Sustained rainfall + flood zone alert (hrs)', threshold: 6, actualValue: 8.2,
      dataSource: 'BRIHANMUMBAI STORM WATER DRAIN (BRIMSTOWAD) + IMD',
      timestamp: new Date('2025-07-21T09:15:00+05:30'),
      location: { lat: 19.2288, lng: 72.8574 },
    },
    estimatedLostHours: 6.0, payoutAmount: paise(1200), status: 'Paid',
    fraudScore: 6, fraudFlags: [],
    processedAt: new Date('2025-07-21T13:00:00+05:30'),
    paidAt: new Date('2025-07-21T13:52:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[9]._id, riderId: RIDERS[9]._id,
    claimNumber: claimNumber(daysAgo(120), 3),
    triggerType: 'SevereAQI',
    triggerData: {
      parameter: 'AQI (CPCB National Standard)', threshold: 400, actualValue: 487,
      dataSource: 'CPCB AQI Monitor — Dwarka Station DL-DW-04, PM2.5: 312µg/m³',
      timestamp: new Date('2025-11-15T10:00:00+05:30'),
      location: { lat: 28.5823, lng: 77.0500 },
    },
    estimatedLostHours: 5.0, payoutAmount: paise(1200), status: 'Paid',
    fraudScore: 2, fraudFlags: [],
    processedAt: new Date('2025-11-15T12:30:00+05:30'),
    paidAt: new Date('2025-11-15T13:10:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[10]._id, riderId: RIDERS[10]._id,
    claimNumber: claimNumber(daysAgo(118), 4),
    triggerType: 'SevereAQI',
    triggerData: {
      parameter: 'AQI (CPCB National Standard)', threshold: 400, actualValue: 523,
      dataSource: 'CPCB AQI Monitor — Rohini Station DL-RO-02, PM2.5: 341µg/m³, PM10: 478µg/m³',
      timestamp: new Date('2025-11-17T08:30:00+05:30'),
      location: { lat: 28.7495, lng: 77.0700 },
    },
    estimatedLostHours: 7.0, payoutAmount: paise(800), status: 'Paid',
    fraudScore: 3, fraudFlags: [],
    processedAt: new Date('2025-11-17T11:00:00+05:30'),
    paidAt: new Date('2025-11-17T11:48:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[17]._id, riderId: RIDERS[17]._id,
    claimNumber: claimNumber(daysAgo(95), 5),
    triggerType: 'SevereAQI',
    triggerData: {
      parameter: 'AQI (CPCB National Standard)', threshold: 400, actualValue: 501,
      dataSource: 'CPCB AQI Monitor — GK Station DL-GK-01, PM2.5: 328µg/m³',
      timestamp: new Date('2025-12-04T09:00:00+05:30'),
      location: { lat: 28.5490, lng: 77.2359 },
    },
    estimatedLostHours: 6.5, payoutAmount: paise(1800), status: 'Paid',
    fraudScore: 1, fraudFlags: [],
    processedAt: new Date('2025-12-04T11:30:00+05:30'),
    paidAt: new Date('2025-12-04T12:15:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[20]._id, riderId: RIDERS[20]._id,
    claimNumber: claimNumber(daysAgo(42), 6),
    triggerType: 'Flooding',
    triggerData: {
      parameter: 'Sustained rainfall + flood zone alert (hrs)', threshold: 6, actualValue: 9.5,
      dataSource: 'IMD Chennai + CWMA Flood Advisory — Adyar River Level 4',
      timestamp: new Date('2025-12-04T06:00:00+05:30'),
      location: { lat: 13.0012, lng: 80.2565 },
    },
    estimatedLostHours: 8.0, payoutAmount: paise(1200), status: 'Paid',
    fraudScore: 5, fraudFlags: [],
    processedAt: new Date('2025-12-04T16:00:00+05:30'),
    paidAt: new Date('2025-12-04T16:40:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[22]._id, riderId: RIDERS[22]._id,
    claimNumber: claimNumber(daysAgo(40), 7),
    triggerType: 'Flooding',
    triggerData: {
      parameter: 'Sustained rainfall + flood zone alert (hrs)', threshold: 6, actualValue: 11.0,
      dataSource: 'IMD Chennai + CWMA Flood Advisory — Buckingham Canal overflow',
      timestamp: new Date('2025-12-06T04:30:00+05:30'),
      location: { lat: 13.0418, lng: 80.2341 },
    },
    estimatedLostHours: 9.0, payoutAmount: paise(800), status: 'Paid',
    fraudScore: 3, fraudFlags: [],
    processedAt: new Date('2025-12-06T14:00:00+05:30'),
    paidAt: new Date('2025-12-06T14:55:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[25]._id, riderId: RIDERS[25]._id,
    claimNumber: claimNumber(daysAgo(29), 8),
    triggerType: 'SocialDisruption',
    triggerData: {
      parameter: 'Admin-verified disruption duration (hrs)', threshold: 4, actualValue: 7.0,
      dataSource: 'Karnataka State Administration — Bandh order verified by RainCheck Admin',
      timestamp: new Date('2025-10-20T06:00:00+05:30'),
      location: { lat: 12.9784, lng: 77.6408 },
    },
    estimatedLostHours: 7.0, payoutAmount: paise(1800), status: 'Paid',
    fraudScore: 0, fraudFlags: [],
    processedAt: new Date('2025-10-20T18:00:00+05:30'),
    paidAt: new Date('2025-10-20T18:30:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[27]._id, riderId: RIDERS[27]._id,
    claimNumber: claimNumber(daysAgo(26), 9),
    triggerType: 'HeavyRain',
    triggerData: {
      parameter: 'Rainfall intensity (mm/hr)', threshold: 64, actualValue: 71.8,
      dataSource: 'OpenWeatherMap + Pune IMD AWS Station PU-KO-03',
      timestamp: new Date('2025-09-14T16:45:00+05:30'),
      location: { lat: 18.5074, lng: 73.8077 },
    },
    estimatedLostHours: 3.5, payoutAmount: paise(1200), status: 'Paid',
    fraudScore: 7, fraudFlags: [],
    processedAt: new Date('2025-09-14T20:30:00+05:30'),
    paidAt: new Date('2025-09-14T21:00:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[30]._id, riderId: RIDERS[30]._id,
    claimNumber: claimNumber(daysAgo(55), 10),
    triggerType: 'Flooding',
    triggerData: {
      parameter: 'Sustained rainfall + flood zone alert (hrs)', threshold: 6, actualValue: 7.8,
      dataSource: 'HDRAA (Hyderabad Disaster Response & Assets Monitoring Authority)',
      timestamp: new Date('2025-09-08T11:30:00+05:30'),
      location: { lat: 17.4849, lng: 78.4138 },
    },
    estimatedLostHours: 6.5, payoutAmount: paise(800), status: 'Paid',
    fraudScore: 4, fraudFlags: [],
    processedAt: new Date('2025-09-08T18:00:00+05:30'),
    paidAt: new Date('2025-09-08T18:45:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[31]._id, riderId: RIDERS[31]._id,
    claimNumber: claimNumber(daysAgo(52), 11),
    triggerType: 'Flooding',
    triggerData: {
      parameter: 'Sustained rainfall + flood zone alert (hrs)', threshold: 6, actualValue: 10.2,
      dataSource: 'HDRAA + GHMC Flood Control Room — Madhapur underpass submerged',
      timestamp: new Date('2025-09-11T07:00:00+05:30'),
      location: { lat: 17.4474, lng: 78.3762 },
    },
    estimatedLostHours: 8.0, payoutAmount: paise(1200), status: 'Approved',
    fraudScore: 2, fraudFlags: [],
    processedAt: new Date('2025-09-11T17:00:00+05:30'),
    paidAt: undefined,
  },
  {
    _id: id(), policyId: POLICIES[32]._id, riderId: RIDERS[32]._id,
    claimNumber: claimNumber(daysAgo(68), 12),
    triggerType: 'HeavyRain',
    triggerData: {
      parameter: 'Rainfall intensity (mm/hr)', threshold: 64, actualValue: 88.1,
      dataSource: 'OpenWeatherMap + IMD Kolkata Station KOL-HW-01',
      timestamp: new Date('2025-08-07T15:00:00+05:30'),
      location: { lat: 22.5958, lng: 88.2636 },
    },
    estimatedLostHours: 5.5, payoutAmount: paise(800), status: 'Paid',
    fraudScore: 8, fraudFlags: [],
    processedAt: new Date('2025-08-07T20:00:00+05:30'),
    paidAt: new Date('2025-08-07T20:40:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[33]._id, riderId: RIDERS[33]._id,
    claimNumber: claimNumber(daysAgo(65), 13),
    triggerType: 'ExtremeHeat',
    triggerData: {
      parameter: 'Feels-like temperature (°C)', threshold: 48, actualValue: 51.4,
      dataSource: 'IMD Jaipur AWS Station JP-VN-01 + OpenWeatherMap',
      timestamp: new Date('2025-05-22T13:15:00+05:30'),
      location: { lat: 26.9124, lng: 75.7873 },
    },
    estimatedLostHours: 5.0, payoutAmount: paise(1800), status: 'Paid',
    fraudScore: 3, fraudFlags: [],
    processedAt: new Date('2025-05-22T18:00:00+05:30'),
    paidAt: new Date('2025-05-22T18:30:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[34]._id, riderId: RIDERS[34]._id,
    claimNumber: claimNumber(daysAgo(63), 14),
    triggerType: 'ExtremeHeat',
    triggerData: {
      parameter: 'Actual temperature (°C)', threshold: 45, actualValue: 47.2,
      dataSource: 'IMD Jaipur Meteorological Center + MAUSAM Station MNR-04',
      timestamp: new Date('2025-05-24T13:00:00+05:30'),
      location: { lat: 26.8580, lng: 75.8150 },
    },
    estimatedLostHours: 4.0, payoutAmount: paise(1200), status: 'Paid',
    fraudScore: 5, fraudFlags: [],
    processedAt: new Date('2025-05-24T17:30:00+05:30'),
    paidAt: new Date('2025-05-24T18:00:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[35]._id, riderId: RIDERS[35]._id,
    claimNumber: claimNumber(daysAgo(14), 15),
    triggerType: 'ExtremeHeat',
    triggerData: {
      parameter: 'Actual temperature (°C)', threshold: 45, actualValue: 46.1,
      dataSource: 'IMD Lucknow AWS Station LKO-HG-02 + OpenWeatherMap',
      timestamp: new Date('2026-02-20T12:30:00+05:30'),
      location: { lat: 26.8467, lng: 80.9462 },
    },
    estimatedLostHours: 3.5, payoutAmount: paise(1200), status: 'Paid',
    fraudScore: 6, fraudFlags: [],
    processedAt: new Date('2026-02-20T16:00:00+05:30'),
    paidAt: new Date('2026-02-20T16:45:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[36]._id, riderId: RIDERS[36]._id,
    claimNumber: claimNumber(daysAgo(11), 16),
    triggerType: 'HeavyRain',
    triggerData: {
      parameter: 'Rainfall intensity (mm/hr)', threshold: 64, actualValue: 69.5,
      dataSource: 'OpenWeatherMap + IMD Mumbai Station MUM-AN-12',
      timestamp: new Date('2026-03-02T15:30:00+05:30'),
      location: { lat: 19.1357, lng: 72.8264 },
    },
    estimatedLostHours: 3.0, payoutAmount: paise(1800), status: 'Approved',
    fraudScore: 4, fraudFlags: [],
    processedAt: new Date('2026-03-02T19:00:00+05:30'),
    paidAt: undefined,
  },
  {
    _id: id(), policyId: POLICIES[37]._id, riderId: RIDERS[37]._id,
    claimNumber: claimNumber(daysAgo(9), 17),
    triggerType: 'SevereAQI',
    triggerData: {
      parameter: 'AQI (CPCB National Standard)', threshold: 400, actualValue: 441,
      dataSource: 'CPCB AQI Monitor — Karol Bagh Station DL-KB-03, PM2.5: 287µg/m³',
      timestamp: new Date('2026-03-05T09:30:00+05:30'),
      location: { lat: 28.6520, lng: 77.1902 },
    },
    estimatedLostHours: 4.5, payoutAmount: paise(800), status: 'Paid',
    fraudScore: 2, fraudFlags: [],
    processedAt: new Date('2026-03-05T12:00:00+05:30'),
    paidAt: new Date('2026-03-05T12:40:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[38]._id, riderId: RIDERS[38]._id,
    claimNumber: claimNumber(daysAgo(7), 18),
    triggerType: 'HeavyRain',
    triggerData: {
      parameter: 'Sustained rainfall >30mm/hr for 3+ hours', threshold: 30, actualValue: 43.2,
      dataSource: 'OpenWeatherMap + IMD Station PUN-HI-05',
      timestamp: new Date('2026-03-07T17:00:00+05:30'),
      location: { lat: 18.5912, lng: 73.7389 },
    },
    estimatedLostHours: 3.5, payoutAmount: paise(1200), status: 'Paid',
    fraudScore: 3, fraudFlags: [],
    processedAt: new Date('2026-03-07T21:00:00+05:30'),
    paidAt: new Date('2026-03-07T21:35:00+05:30'),
  },

  // ── 5 AUTO-INITIATED (just processing) ───────────────────────────────────
  {
    _id: id(), policyId: POLICIES[2]._id, riderId: RIDERS[2]._id,
    claimNumber: claimNumber(daysAgo(0), 19),
    triggerType: 'HeavyRain',
    triggerData: {
      parameter: 'Rainfall intensity (mm/hr)', threshold: 64, actualValue: 81.7,
      dataSource: 'OpenWeatherMap Real-time — Mumbai Radar Station',
      timestamp: hoursAgo(2),
      location: { lat: 19.0177, lng: 72.8428 },
    },
    estimatedLostHours: 3.5, payoutAmount: paise(1800), status: 'AutoInitiated',
    fraudScore: 5, fraudFlags: [],
  },
  {
    _id: id(), policyId: POLICIES[4]._id, riderId: RIDERS[4]._id,
    claimNumber: claimNumber(daysAgo(0), 20),
    triggerType: 'HeavyRain',
    triggerData: {
      parameter: 'Rainfall intensity (mm/hr)', threshold: 64, actualValue: 74.4,
      dataSource: 'OpenWeatherMap Real-time — Chembur IMD AWS',
      timestamp: hoursAgo(3),
      location: { lat: 19.0626, lng: 72.9010 },
    },
    estimatedLostHours: 3.0, payoutAmount: paise(1200), status: 'AutoInitiated',
    fraudScore: 6, fraudFlags: [],
  },
  {
    _id: id(), policyId: POLICIES[12]._id, riderId: RIDERS[12]._id,
    claimNumber: claimNumber(daysAgo(1), 21),
    triggerType: 'SevereAQI',
    triggerData: {
      parameter: 'AQI (CPCB National Standard)', threshold: 400, actualValue: 462,
      dataSource: 'CPCB AQI Monitor — Lajpat Nagar Station DL-LN-01, PM2.5: 298µg/m³',
      timestamp: hoursAgo(18),
      location: { lat: 28.5677, lng: 77.2434 },
    },
    estimatedLostHours: 5.5, payoutAmount: paise(1800), status: 'AutoInitiated',
    fraudScore: 1, fraudFlags: [],
  },
  {
    _id: id(), policyId: POLICIES[24]._id, riderId: RIDERS[24]._id,
    claimNumber: claimNumber(daysAgo(1), 22),
    triggerType: 'ExtremeHeat',
    triggerData: {
      parameter: 'Feels-like temperature (°C)', threshold: 48, actualValue: 49.8,
      dataSource: 'OpenWeatherMap + IMD Hyderabad Station HYD-GC-01',
      timestamp: hoursAgo(20),
      location: { lat: 17.4401, lng: 78.3489 },
    },
    estimatedLostHours: 4.0, payoutAmount: paise(1200), status: 'AutoInitiated',
    fraudScore: 3, fraudFlags: [],
  },
  {
    _id: id(), policyId: POLICIES[39]._id, riderId: RIDERS[39]._id,
    claimNumber: claimNumber(daysAgo(0), 23),
    triggerType: 'HeavyRain',
    triggerData: {
      parameter: 'Rainfall intensity (mm/hr)', threshold: 64, actualValue: 67.9,
      dataSource: 'OpenWeatherMap Real-time — Lucknow IMD Station LKO-GN-03',
      timestamp: hoursAgo(1),
      location: { lat: 26.8599, lng: 81.0014 },
    },
    estimatedLostHours: 2.5, payoutAmount: paise(1800), status: 'AutoInitiated',
    fraudScore: 9, fraudFlags: [],
  },

  // ── 3 REJECTED ────────────────────────────────────────────────────────────
  {
    _id: id(), policyId: POLICIES[5]._id, riderId: RIDERS[5]._id,
    claimNumber: claimNumber(daysAgo(30), 24),
    triggerType: 'HeavyRain',
    triggerData: {
      parameter: 'Rainfall intensity (mm/hr)', threshold: 64, actualValue: 58.2,
      dataSource: 'OpenWeatherMap (Unverified — peak reading not sustained)',
      timestamp: new Date('2025-09-19T17:00:00+05:30'),
      location: { lat: 19.0388, lng: 72.8617 },
    },
    estimatedLostHours: 2.0, payoutAmount: 0, status: 'Rejected',
    fraudScore: 12, fraudFlags: ['rainfall_below_threshold', 'reading_not_sustained_3hr'],
    processedAt: new Date('2025-09-20T10:00:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[15]._id, riderId: RIDERS[15]._id,
    claimNumber: claimNumber(daysAgo(22), 25),
    triggerType: 'ExtremeHeat',
    triggerData: {
      parameter: 'Actual temperature (°C)', threshold: 45, actualValue: 43.7,
      dataSource: 'OpenWeatherMap (Station malfunction suspected)',
      timestamp: new Date('2025-05-29T13:00:00+05:30'),
      location: { lat: 28.6520, lng: 77.1902 },
    },
    estimatedLostHours: 3.0, payoutAmount: 0, status: 'Rejected',
    fraudScore: 18, fraudFlags: ['temperature_below_threshold', 'secondary_source_mismatch'],
    processedAt: new Date('2025-05-30T09:00:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[19]._id, riderId: RIDERS[19]._id,
    claimNumber: claimNumber(daysAgo(18), 26),
    triggerType: 'SocialDisruption',
    triggerData: {
      parameter: 'Admin-verified disruption duration (hrs)', threshold: 4, actualValue: 2.5,
      dataSource: 'Community Report (Not admin-verified — rumour of strike not confirmed)',
      timestamp: new Date('2025-10-01T08:00:00+05:30'),
      location: { lat: 19.2183, lng: 72.9781 },
    },
    estimatedLostHours: 2.5, payoutAmount: 0, status: 'Rejected',
    fraudScore: 22, fraudFlags: ['disruption_not_admin_verified', 'duration_below_threshold'],
    processedAt: new Date('2025-10-02T10:00:00+05:30'),
  },

  // ── 2 FRAUD SUSPECTED ─────────────────────────────────────────────────────
  {
    _id: id(), policyId: POLICIES[3]._id, riderId: RIDERS[3]._id,
    claimNumber: claimNumber(daysAgo(16), 27),
    triggerType: 'HeavyRain',
    triggerData: {
      parameter: 'Rainfall intensity (mm/hr)', threshold: 64, actualValue: 76.5,
      dataSource: 'OpenWeatherMap (GPS location mismatch — rider 8.2km from claimed zone)',
      timestamp: new Date('2025-07-25T14:00:00+05:30'),
      location: { lat: 19.0728, lng: 72.8826 },
    },
    estimatedLostHours: 4.0, payoutAmount: 0, status: 'FraudSuspected',
    fraudScore: 78,
    fraudFlags: [
      'gps_location_mismatch_8.2km',
      'claimed_zone_different_from_gps',
      'second_claim_within_14_days',
      'policy_age_less_than_7_days',
    ],
    processedAt: new Date('2025-07-25T18:00:00+05:30'),
  },
  {
    _id: id(), policyId: POLICIES[6]._id, riderId: RIDERS[6]._id,
    claimNumber: claimNumber(daysAgo(10), 28),
    triggerType: 'SevereAQI',
    triggerData: {
      parameter: 'AQI (CPCB National Standard)', threshold: 400, actualValue: 415,
      dataSource: 'OpenWeatherMap (Duplicate submission — identical to CLM-20250920-00012)',
      timestamp: new Date('2025-09-21T10:00:00+05:30'),
      location: { lat: 19.1871, lng: 72.8486 },
    },
    estimatedLostHours: 5.0, payoutAmount: 0, status: 'FraudSuspected',
    fraudScore: 85,
    fraudFlags: [
      'duplicate_claim_detected',
      'identical_trigger_timestamp',
      'multiple_accounts_same_phone_pattern',
      'claim_submitted_from_different_city',
    ],
    processedAt: new Date('2025-09-21T14:00:00+05:30'),
  },

  // ── 2 UNDER REVIEW ────────────────────────────────────────────────────────
  {
    _id: id(), policyId: POLICIES[8]._id, riderId: RIDERS[8]._id,
    claimNumber: claimNumber(daysAgo(3), 29),
    triggerType: 'Flooding',
    triggerData: {
      parameter: 'Sustained rainfall + flood zone alert (hrs)', threshold: 6, actualValue: 6.8,
      dataSource: 'IMD + Manual verification pending — conflicting reports from Thane Municipal',
      timestamp: new Date('2026-03-11T08:30:00+05:30'),
      location: { lat: 19.2183, lng: 72.9781 },
    },
    estimatedLostHours: 5.5, payoutAmount: paise(800), status: 'UnderReview',
    fraudScore: 24, fraudFlags: ['flood_zone_boundary_ambiguous', 'manual_verification_required'],
    processedAt: undefined,
  },
  {
    _id: id(), policyId: POLICIES[16]._id, riderId: RIDERS[16]._id,
    claimNumber: claimNumber(daysAgo(2), 30),
    triggerType: 'ExtremeHeat',
    triggerData: {
      parameter: 'Actual temperature (°C)', threshold: 45, actualValue: 45.3,
      dataSource: 'OpenWeatherMap (Borderline reading — cross-referencing IMD station data)',
      timestamp: new Date('2026-03-12T12:45:00+05:30'),
      location: { lat: 28.5244, lng: 77.2066 },
    },
    estimatedLostHours: 3.0, payoutAmount: paise(1800), status: 'UnderReview',
    fraudScore: 15, fraudFlags: ['borderline_threshold_value', 'single_source_reading'],
    processedAt: undefined,
  },
];

// ─── DISRUPTION EVENTS (15 historical events) ─────────────────────────────────

export const DISRUPTION_EVENTS: SeedDisruptionEvent[] = [
  {
    _id: id(), city: 'Mumbai',
    zones: ['Andheri West', 'Andheri East', 'Borivali', 'Dahisar', 'Kandivali'],
    type: 'Flooding', severity: 'Extreme',
    title: 'Mumbai Monsoon Mega Flood — Andheri-Borivali Corridor',
    description: 'Extremely heavy rainfall of 127mm recorded between 11am-4pm caused widespread waterlogging across the western suburbs. The Mithi River breached danger level at 8.2m (danger mark: 5.8m). BEST bus services suspended, Western Railway local trains stopped for 3 hours. 12 riders with active policies lost a full day of earnings.',
    startTime: new Date('2025-07-18T11:00:00+05:30'),
    endTime: new Date('2025-07-18T21:00:00+05:30'),
    triggerData: { parameter: 'Rainfall intensity (mm/hr)', value: 127, threshold: 64 },
    affectedRiders: 12, totalPayouts: paise(14400), claimsGenerated: 12,
    isActive: false, source: 'Automated',
  },
  {
    _id: id(), city: 'Delhi',
    zones: ['Dwarka', 'Rohini', 'Pitampura', 'Janakpuri', 'Paschim Vihar', 'Karol Bagh', 'Saket', 'Greater Kailash'],
    type: 'SevereAQI', severity: 'Extreme',
    title: 'Delhi Winter Smog Crisis — AQI 520 City-Wide',
    description: 'Prolonged severe air quality event driven by stubble burning from Haryana and Punjab combined with calm winds and low temperature inversion. AQI sustained above 450 for 6 consecutive days. GRAP Stage IV (Emergency) restrictions imposed. IMD forecast: no relief for 4 days. 45 riders across Delhi affected — the single largest payout event in RainCheck history.',
    startTime: new Date('2025-11-13T00:00:00+05:30'),
    endTime: new Date('2025-11-19T06:00:00+05:30'),
    triggerData: { parameter: 'AQI (CPCB National Standard)', value: 520, threshold: 400 },
    affectedRiders: 45, totalPayouts: paise(52200), claimsGenerated: 45,
    isActive: false, source: 'Automated',
  },
  {
    _id: id(), city: 'Chennai',
    zones: ['Velachery', 'Adyar', 'Tambaram', 'Porur', 'T. Nagar', 'Anna Nagar', 'Sholinganallur'],
    type: 'Flooding', severity: 'Extreme',
    title: 'Cyclone Michaung Aftermath — Chennai Catastrophic Flooding',
    description: 'In the wake of Cyclone Michaung making landfall near Bapatla, Andhra Pradesh, Chennai received 500mm+ of rain over 48 hours. The Adyar and Cooum rivers breached banks simultaneously. IT corridor submerged, airport closed for 12 hours. 28 riders affected across all policy tiers.',
    startTime: new Date('2023-12-04T00:00:00+05:30'),
    endTime: new Date('2023-12-06T18:00:00+05:30'),
    triggerData: { parameter: 'Sustained rainfall >30mm/hr (hrs)', value: 38, threshold: 6 },
    affectedRiders: 28, totalPayouts: paise(33600), claimsGenerated: 28,
    isActive: false, source: 'Automated',
  },
  {
    _id: id(), city: 'Hyderabad',
    zones: ['Kukatpally', 'Madhapur', 'Gachibowli', 'LB Nagar', 'Uppal', 'Miyapur'],
    type: 'Flooding', severity: 'Severe',
    title: 'Hyderabad Flash Floods — Musi River Overflow',
    description: 'Intense rainfall of 93mm in 5 hours caused the Musi River to overflow at Necklace Road. The Kukatpally Housing Board (KPHB) and Madhapur low-lying areas were submerged. GHMC declared holiday. 18 riders could not operate for 7+ hours.',
    startTime: new Date('2025-09-08T06:00:00+05:30'),
    endTime: new Date('2025-09-08T20:00:00+05:30'),
    triggerData: { parameter: 'Rainfall intensity (mm/hr)', value: 93, threshold: 64 },
    affectedRiders: 18, totalPayouts: paise(21600), claimsGenerated: 18,
    isActive: false, source: 'Automated',
  },
  {
    _id: id(), city: 'Bangalore',
    zones: ['Koramangala', 'Indiranagar', 'Whitefield', 'HSR Layout', 'BTM Layout', 'Electronic City', 'Marathahalli'],
    type: 'SocialDisruption', severity: 'Severe',
    title: 'Karnataka Bandh — Cauvery Water Dispute',
    description: 'Karnataka Rakshana Vedike called a complete bandh across the state in protest against Supreme Court\'s Cauvery water sharing order. All shops, restaurants, and offices shut. Food delivery demand dropped to zero. 22 Bangalore riders with active policies affected for the full day.',
    startTime: new Date('2025-10-20T06:00:00+05:30'),
    endTime: new Date('2025-10-20T23:59:00+05:30'),
    triggerData: { parameter: 'Admin-verified disruption duration (hrs)', value: 18, threshold: 4 },
    affectedRiders: 22, totalPayouts: paise(26400), claimsGenerated: 22,
    isActive: false, source: 'AdminTriggered',
  },
  {
    _id: id(), city: 'Delhi',
    zones: ['Saket', 'Lajpat Nagar', 'Greater Kailash', 'Hauz Khas', 'Malviya Nagar'],
    type: 'ExtremeHeat', severity: 'Severe',
    title: 'Delhi Heat Wave — IMD Red Alert, Feels-Like 51°C',
    description: 'IMD issued Red Alert as Delhi recorded 47.8°C actual temperature and 51.4°C feels-like index. This was the 4th consecutive day above 45°C. DDMA advisory: outdoor workers to limit exposure between 11am-4pm. 17 Delhi riders triggered heat wave payouts.',
    startTime: new Date('2025-05-22T10:00:00+05:30'),
    endTime: new Date('2025-05-22T19:00:00+05:30'),
    triggerData: { parameter: 'Feels-like temperature (°C)', value: 51.4, threshold: 48 },
    affectedRiders: 17, totalPayouts: paise(20400), claimsGenerated: 17,
    isActive: false, source: 'Automated',
  },
  {
    _id: id(), city: 'Jaipur',
    zones: ['Vaishali Nagar', 'Malviya Nagar', 'C-Scheme', 'Mansarovar', 'Jagatpura'],
    type: 'ExtremeHeat', severity: 'Severe',
    title: 'Jaipur Scorching Heat Wave — 47.2°C Peak',
    description: 'Jaipur baked under a relentless heat wave with temperatures crossing 47°C for 3 consecutive days. Rajasthan government declared a health emergency and shut schools. Feels-like temperature hit 51.4°C on peak day. 14 Jaipur riders claimed heat wave payouts.',
    startTime: new Date('2025-05-21T11:00:00+05:30'),
    endTime: new Date('2025-05-24T18:00:00+05:30'),
    triggerData: { parameter: 'Actual temperature (°C)', value: 47.2, threshold: 45 },
    affectedRiders: 14, totalPayouts: paise(16800), claimsGenerated: 14,
    isActive: false, source: 'Automated',
  },
  {
    _id: id(), city: 'Kolkata',
    zones: ['Howrah', 'Shibpur', 'New Town', 'Rajarhat', 'Salt Lake'],
    type: 'HeavyRain', severity: 'Severe',
    title: 'Kolkata Pre-Cyclone Rainfall — 88mm/hr in Howrah',
    description: 'A deep depression in the Bay of Bengal intensified causing extremely heavy rains over Kolkata and Howrah districts. Rainfall of 88mm/hr recorded at Howrah Meteorological Station. The Hooghly River rose 1.8m above danger mark. Ferry services halted. 11 Kolkata riders affected.',
    startTime: new Date('2025-08-07T14:00:00+05:30'),
    endTime: new Date('2025-08-07T22:00:00+05:30'),
    triggerData: { parameter: 'Rainfall intensity (mm/hr)', value: 88.1, threshold: 64 },
    affectedRiders: 11, totalPayouts: paise(8800), claimsGenerated: 11,
    isActive: false, source: 'Automated',
  },
  {
    _id: id(), city: 'Pune',
    zones: ['Kothrud', 'Hinjawadi', 'Pimple Saudagar', 'Wakad', 'Baner'],
    type: 'HeavyRain', severity: 'Moderate',
    title: 'Pune Monsoon Surge — 71mm/hr in Hinjawadi IT Hub',
    description: 'Heavy downpour of 71mm/hr struck the Hinjawadi-Wakad tech corridor and residential areas of Kothrud during peak delivery hours (5pm-9pm). Mumbai-Pune Expressway partially closed. Several low-lying apartment complexes waterlogged. 8 Pune riders impacted.',
    startTime: new Date('2025-09-14T16:30:00+05:30'),
    endTime: new Date('2025-09-14T23:00:00+05:30'),
    triggerData: { parameter: 'Rainfall intensity (mm/hr)', value: 71.8, threshold: 64 },
    affectedRiders: 8, totalPayouts: paise(9600), claimsGenerated: 8,
    isActive: false, source: 'Automated',
  },
  {
    _id: id(), city: 'Mumbai',
    zones: ['Borivali', 'Kandivali', 'Malad', 'Goregaon'],
    type: 'Flooding', severity: 'Moderate',
    title: 'Borivali-Kandivali Waterlogging — 3-Hour Commuter Standstill',
    description: 'Western Railway lines blocked between Borivali and Kandivali due to track flooding at Charkop. SV Road completely inundated. Auto-rickshaws stranded. 9 riders in the area lost 3-5 hours of earning window.',
    startTime: new Date('2025-07-21T09:00:00+05:30'),
    endTime: new Date('2025-07-21T15:00:00+05:30'),
    triggerData: { parameter: 'Sustained rainfall + flood zone (hrs)', value: 8.2, threshold: 6 },
    affectedRiders: 9, totalPayouts: paise(10800), claimsGenerated: 9,
    isActive: false, source: 'Automated',
  },
  {
    _id: id(), city: 'Delhi',
    zones: ['Lajpat Nagar', 'Karol Bagh', 'Saket', 'Pitampura', 'Rohini'],
    type: 'SevereAQI', severity: 'Extreme',
    title: 'Delhi Emergency AQI 501 — GRAP Stage IV Invoked',
    description: 'AQI crossed 500 (Hazardous) for the first time in 3 years. GRAP Stage IV restrictions: ban on diesel vehicles, construction halt, school closure. Swiggy and Zomato both issued voluntary rider safety advisories recommending stopping work. 19 affected riders paid out.',
    startTime: new Date('2025-12-04T00:00:00+05:30'),
    endTime: new Date('2025-12-05T18:00:00+05:30'),
    triggerData: { parameter: 'AQI (CPCB National Standard)', value: 501, threshold: 400 },
    affectedRiders: 19, totalPayouts: paise(34200), claimsGenerated: 19,
    isActive: false, source: 'Automated',
  },
  {
    _id: id(), city: 'Chennai',
    zones: ['Anna Nagar', 'T. Nagar', 'Porur', 'Velachery'],
    type: 'HeavyRain', severity: 'Moderate',
    title: 'Chennai Northeast Monsoon Burst — 69mm/hr, Peak Hours',
    description: 'Northeast monsoon intensified overnight bringing 69mm/hr rainfall during the 6am-10am peak breakfast delivery window. Poonamallee bypass and GST road waterlogged. MRTS services delayed by 45 minutes. 7 Chennai riders impacted.',
    startTime: new Date('2025-11-08T06:00:00+05:30'),
    endTime: new Date('2025-11-08T13:00:00+05:30'),
    triggerData: { parameter: 'Rainfall intensity (mm/hr)', value: 69.3, threshold: 64 },
    affectedRiders: 7, totalPayouts: paise(8400), claimsGenerated: 7,
    isActive: false, source: 'Automated',
  },
  {
    _id: id(), city: 'Ahmedabad',
    zones: ['Navrangpura', 'Bopal', 'Satellite', 'Prahlad Nagar'],
    type: 'ExtremeHeat', severity: 'Moderate',
    title: 'Ahmedabad Summer Heat Alert — 44.8°C Actual, 47.9°C Feels-Like',
    description: 'Gujarat entered severe heat wave conditions. Ahmedabad crossed 44.8°C actual temperature with relative humidity amplifying feels-like to 47.9°C. AMC issued heat advisory. While triggers were borderline, 2 riders with Premium plans successfully claimed under the feels-like threshold.',
    startTime: new Date('2025-04-29T11:00:00+05:30'),
    endTime: new Date('2025-04-29T18:30:00+05:30'),
    triggerData: { parameter: 'Feels-like temperature (°C)', value: 47.9, threshold: 48 },
    affectedRiders: 2, totalPayouts: paise(3600), claimsGenerated: 2,
    isActive: false, source: 'Automated',
  },
  {
    _id: id(), city: 'Mumbai',
    zones: ['Andheri West', 'Vile Parle', 'Santacruz'],
    type: 'HeavyRain', severity: 'Severe',
    title: 'Mumbai Airport Zone Flash Rain — 81mm/hr, Active Trigger NOW',
    description: 'Sudden intense convective rainfall over the Mumbai airport zone. IMD Doppler radar confirmed 81.7mm/hr at Andheri. CSIA runways reported surface flooding. Western express highway traffic at standstill. 3 active policies auto-triggered payouts.',
    startTime: hoursAgo(2),
    endTime: undefined,
    triggerData: { parameter: 'Rainfall intensity (mm/hr)', value: 81.7, threshold: 64 },
    affectedRiders: 3, totalPayouts: paise(5400), claimsGenerated: 3,
    isActive: true, source: 'Automated',
  },
  {
    _id: id(), city: 'Delhi',
    zones: ['Lajpat Nagar', 'Karol Bagh', 'Greater Kailash', 'Saket', 'Hauz Khas', 'Rohini', 'Dwarka'],
    type: 'SevereAQI', severity: 'Severe',
    title: 'Delhi AQI 462 — Active Disruption, GRAP Stage III',
    description: 'AQI has crossed 462 across central and south Delhi monitoring stations as of this morning. CPCB has invoked GRAP Stage III restrictions. Visibility dropped to 200m in some areas. 4 active policies being evaluated for payout.',
    startTime: hoursAgo(18),
    endTime: undefined,
    triggerData: { parameter: 'AQI (CPCB National Standard)', value: 462, threshold: 400 },
    affectedRiders: 4, totalPayouts: paise(0), claimsGenerated: 4,
    isActive: true, source: 'Automated',
  },
];

// ─── CITY RISK PROFILES ───────────────────────────────────────────────────────

export const CITY_RISK_PROFILES: CityRiskProfile[] = [
  {
    city: 'Mumbai',
    baseRiskScore: 72,
    topRisks: ['Flooding', 'HeavyRain', 'SocialDisruption'],
    avgDisruptionsPerMonth: 3.2,
    worstMonths: ['June', 'July', 'August', 'September'],
    avgPremiumMultiplier: 1.35,
    floodProneZones: ['Andheri', 'Borivali', 'Dadar', 'Sion', 'Kurla', 'Chembur', 'Thane', 'Dharavi', 'Bandra'],
    historicalAvgRainfall: { monsoon: 2166, winter: 3, summer: 15 },
    avgAQI: { winter: 148, summer: 89, monsoon: 62 },
  },
  {
    city: 'Delhi',
    baseRiskScore: 88,
    topRisks: ['SevereAQI', 'ExtremeHeat', 'SocialDisruption'],
    avgDisruptionsPerMonth: 4.1,
    worstMonths: ['May', 'June', 'November', 'December'],
    avgPremiumMultiplier: 1.45,
    floodProneZones: ['Yamuna Khadar', 'Mayur Vihar', 'Patparganj', 'Loni Road'],
    historicalAvgRainfall: { monsoon: 797, winter: 22, summer: 28 },
    avgAQI: { winter: 312, summer: 180, monsoon: 95 },
  },
  {
    city: 'Bangalore',
    baseRiskScore: 34,
    topRisks: ['HeavyRain', 'SocialDisruption'],
    avgDisruptionsPerMonth: 1.1,
    worstMonths: ['September', 'October'],
    avgPremiumMultiplier: 0.90,
    floodProneZones: ['Ejipura', 'Silk Board', 'Hebbal', 'KR Puram'],
    historicalAvgRainfall: { monsoon: 972, winter: 38, summer: 45 },
    avgAQI: { winter: 98, summer: 75, monsoon: 55 },
  },
  {
    city: 'Chennai',
    baseRiskScore: 68,
    topRisks: ['Flooding', 'HeavyRain', 'ExtremeHeat'],
    avgDisruptionsPerMonth: 2.4,
    worstMonths: ['October', 'November', 'December'],
    avgPremiumMultiplier: 1.20,
    floodProneZones: ['Adyar', 'Velachery', 'Tambaram', 'Mudichur', 'Sholinganallur', 'Porur'],
    historicalAvgRainfall: { monsoon: 1400, winter: 290, summer: 82 },
    avgAQI: { winter: 118, summer: 102, monsoon: 72 },
  },
  {
    city: 'Hyderabad',
    baseRiskScore: 55,
    topRisks: ['Flooding', 'HeavyRain', 'ExtremeHeat'],
    avgDisruptionsPerMonth: 1.8,
    worstMonths: ['July', 'August', 'September'],
    avgPremiumMultiplier: 1.10,
    floodProneZones: ['Kukatpally', 'Madhapur', 'LB Nagar', 'Falaknuma', 'Moosarambagh'],
    historicalAvgRainfall: { monsoon: 790, winter: 15, summer: 30 },
    avgAQI: { winter: 142, summer: 115, monsoon: 68 },
  },
  {
    city: 'Kolkata',
    baseRiskScore: 64,
    topRisks: ['HeavyRain', 'Flooding', 'SocialDisruption'],
    avgDisruptionsPerMonth: 2.6,
    worstMonths: ['June', 'July', 'August'],
    avgPremiumMultiplier: 1.25,
    floodProneZones: ['Howrah', 'Shibpur', 'Tiljala', 'Topsia', 'Garden Reach'],
    historicalAvgRainfall: { monsoon: 1582, winter: 28, summer: 65 },
    avgAQI: { winter: 198, summer: 105, monsoon: 75 },
  },
  {
    city: 'Pune',
    baseRiskScore: 48,
    topRisks: ['HeavyRain', 'Flooding'],
    avgDisruptionsPerMonth: 1.5,
    worstMonths: ['July', 'August', 'September'],
    avgPremiumMultiplier: 1.05,
    floodProneZones: ['Katraj', 'Sinhagad Road', 'Kothrud Low-lying', 'Sangamwadi'],
    historicalAvgRainfall: { monsoon: 722, winter: 10, summer: 18 },
    avgAQI: { winter: 122, summer: 95, monsoon: 58 },
  },
  {
    city: 'Ahmedabad',
    baseRiskScore: 51,
    topRisks: ['ExtremeHeat', 'SevereAQI'],
    avgDisruptionsPerMonth: 1.2,
    worstMonths: ['April', 'May', 'June'],
    avgPremiumMultiplier: 1.00,
    floodProneZones: ['Odhav', 'Vatva', 'Nikol'],
    historicalAvgRainfall: { monsoon: 482, winter: 4, summer: 5 },
    avgAQI: { winter: 155, summer: 178, monsoon: 82 },
  },
  {
    city: 'Jaipur',
    baseRiskScore: 71,
    topRisks: ['ExtremeHeat', 'HeavyRain'],
    avgDisruptionsPerMonth: 2.0,
    worstMonths: ['April', 'May', 'June', 'July'],
    avgPremiumMultiplier: 1.15,
    floodProneZones: ['Mansarovar Low-lying', 'Sanganer', 'Murlipura'],
    historicalAvgRainfall: { monsoon: 644, winter: 12, summer: 8 },
    avgAQI: { winter: 172, summer: 210, monsoon: 88 },
  },
  {
    city: 'Lucknow',
    baseRiskScore: 63,
    topRisks: ['ExtremeHeat', 'SevereAQI', 'HeavyRain'],
    avgDisruptionsPerMonth: 1.9,
    worstMonths: ['May', 'June', 'November', 'December'],
    avgPremiumMultiplier: 1.15,
    floodProneZones: ['Gomti Nagar Extension', 'Rajajipuram', 'Telibagh'],
    historicalAvgRainfall: { monsoon: 825, winter: 20, summer: 18 },
    avgAQI: { winter: 245, summer: 168, monsoon: 98 },
  },
];

// ─── PREMIUM CALCULATION REFERENCE TABLE ──────────────────────────────────────

export const PREMIUM_CALCULATION_TABLE = {
  basePremiums: {
    Basic:    { paise: paise(32),  coverage: 'HeavyRain + ExtremeHeat only',     maxPayout: paise(800)  },
    Standard: { paise: paise(52),  coverage: '4 triggers (excl. SocialDisruption)', maxPayout: paise(1200) },
    Premium:  { paise: paise(72),  coverage: 'All 5 triggers',                   maxPayout: paise(1800) },
  },
  cityMultipliers: {
    Delhi:      1.45,  // Highest — extreme AQI + heat
    Mumbai:     1.35,  // High flood + rain risk
    Kolkata:    1.25,  // Monsoon + cyclone proximity
    Chennai:    1.20,  // Cyclone + NE monsoon
    Jaipur:     1.15,  // Heat + dust storms
    Lucknow:    1.15,  // Heat + winter AQI
    Hyderabad:  1.10,  // Flash floods
    Pune:       1.05,  // Moderate rain risk
    Ahmedabad:  1.00,  // Baseline city
    Bangalore:  0.90,  // Lowest risk city
  },
  zoneAdjustments: {
    'Flood-prone zone':          +0.20,
    'Normal urban zone':          0.00,
    'Low-risk tech corridor':    -0.05,
    'Upmarket low-density zone': -0.10,
  },
  seasonalAdjustments: {
    'Monsoon (Jun-Sep)':    +0.15,
    'Delhi/UP Winter (Nov-Jan)': +0.20,
    'Summer peak (Apr-Jun)': +0.10,
    'Off-season':            0.00,
  },
  experienceDiscounts: {
    '<12 months':    0.00,
    '12-24 months': -0.05,
    '>24 months':   -0.10,
  },
  claimsHistoryAdjustments: {
    '0 claims (last 4 weeks)':  0.00,
    '1 claim (last 4 weeks)':  +0.05,
    '2 claims (last 4 weeks)': +0.10,
    '3+ claims (last 4 weeks)':+0.20,
  },
  exampleCalculations: [
    {
      scenario: 'Priya Sharma — Delhi, Standard plan, 19 months exp, 0 prior claims',
      base: paise(52),
      cityMult: 1.45,
      expDiscount: 0.95,
      seasonAdj: 1.20,
      claimsAdj: 1.00,
      finalPremium: paise(86),
      finalPremiumINR: 86,
    },
    {
      scenario: 'Suresh Babu — Bangalore, Basic plan, 6 months exp, 0 prior claims',
      base: paise(32),
      cityMult: 0.90,
      expDiscount: 1.00,
      seasonAdj: 1.00,
      claimsAdj: 1.00,
      finalPremium: paise(29),
      finalPremiumINR: 29,
    },
    {
      scenario: 'Vikram Shinde — Mumbai, Premium plan, 41 months exp, 1 prior claim',
      base: paise(72),
      cityMult: 1.35,
      expDiscount: 0.90,
      seasonAdj: 1.15,
      claimsAdj: 1.05,
      finalPremium: paise(105),
      finalPremiumINR: 105,
    },
  ],
};
