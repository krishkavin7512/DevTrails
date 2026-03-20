import mongoose, { Schema, Document } from 'mongoose';

export interface IRider extends Document {
  fullName: string;
  phone: string;
  email?: string;
  city: 'Mumbai' | 'Delhi' | 'Bangalore' | 'Chennai' | 'Hyderabad' | 'Kolkata' | 'Pune' | 'Ahmedabad' | 'Jaipur' | 'Lucknow';
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

const RiderSchema = new Schema<IRider>(
  {
    fullName: { type: String, required: true, trim: true },
    phone: {
      type: String,
      required: true,
      unique: true,
      match: /^[6-9]\d{9}$/,
    },
    email: { type: String, lowercase: true, trim: true },
    city: {
      type: String,
      required: true,
      enum: ['Mumbai', 'Delhi', 'Bangalore', 'Chennai', 'Hyderabad', 'Kolkata', 'Pune', 'Ahmedabad', 'Jaipur', 'Lucknow'],
    },
    platform: { type: String, required: true, enum: ['Zomato', 'Swiggy', 'Both'] },
    operatingZone: { type: String, required: true },
    operatingPincode: { type: String, required: true, match: /^\d{6}$/ },
    avgWeeklyEarnings: { type: Number, required: true, min: 200000, max: 600000 },
    avgDailyHours: { type: Number, required: true, min: 6, max: 14 },
    preferredShift: {
      type: String,
      required: true,
      enum: ['Morning', 'Afternoon', 'Evening', 'Night', 'Mixed'],
    },
    vehicleType: { type: String, required: true, enum: ['Bicycle', 'Scooter', 'Motorcycle'] },
    experienceMonths: { type: Number, required: true, min: 1, max: 60 },
    riskTier: { type: String, required: true, enum: ['Low', 'Medium', 'High', 'VeryHigh'] },
    riskScore: { type: Number, required: true, min: 0, max: 100 },
    isActive: { type: Boolean, default: true },
    kycVerified: { type: Boolean, default: false },
    registeredAt: { type: Date, default: Date.now },
    lastActiveAt: { type: Date, default: Date.now },
    location: {
      lat: { type: Number, required: true },
      lng: { type: Number, required: true },
    },
  },
  { timestamps: true }
);

RiderSchema.index({ city: 1, riskTier: 1 });
RiderSchema.index({ 'location.lat': 1, 'location.lng': 1 });

export default mongoose.model<IRider>('Rider', RiderSchema);
