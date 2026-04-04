import mongoose, { Schema, Document } from 'mongoose';

export interface ITriggerData {
  parameter: string;
  threshold: number;
  actualValue: number;
  dataSource: string;
  timestamp: Date;
  location: { lat: number; lng: number };
}

export interface IClaim extends Document {
  policyId: mongoose.Types.ObjectId;
  riderId: mongoose.Types.ObjectId;
  claimNumber: string;
  triggerType: 'HeavyRain' | 'ExtremeHeat' | 'SevereAQI' | 'Flooding' | 'SocialDisruption';
  triggerData: ITriggerData;
  estimatedLostHours: number;
  payoutAmount: number;
  status: 'AutoInitiated' | 'UnderReview' | 'Approved' | 'Paid' | 'Rejected' | 'FraudSuspected';
  fraudScore: number;
  fraudFlags: string[];
  deviceFingerprint?: { hash: string; clientId: string };
  adminNote?: string;
  reviewedAt?: Date;
  processedAt?: Date;
  paidAt?: Date;
  appealedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const ClaimSchema = new Schema<IClaim>(
  {
    policyId: { type: Schema.Types.ObjectId, ref: 'Policy', required: true },
    riderId: { type: Schema.Types.ObjectId, ref: 'Rider', required: true },
    claimNumber: { type: String, required: true, unique: true },
    triggerType: {
      type: String,
      required: true,
      enum: ['HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding', 'SocialDisruption'],
    },
    triggerData: {
      parameter: { type: String, required: true },
      threshold: { type: Number, required: true },
      actualValue: { type: Number, required: true },
      dataSource: { type: String, required: true },
      timestamp: { type: Date, required: true },
      location: {
        lat: { type: Number, required: true },
        lng: { type: Number, required: true },
      },
    },
    estimatedLostHours: { type: Number, required: true, min: 0 },
    payoutAmount: { type: Number, required: true, min: 0 },
    status: {
      type: String,
      required: true,
      enum: ['AutoInitiated', 'UnderReview', 'Approved', 'Paid', 'Rejected', 'FraudSuspected'],
      default: 'AutoInitiated',
    },
    fraudScore: { type: Number, default: 0, min: 0, max: 100 },
    fraudFlags: [{ type: String }],
    deviceFingerprint: {
      hash:     { type: String },
      clientId: { type: String },
    },
    adminNote:   { type: String },
    reviewedAt:  { type: Date },
    processedAt: { type: Date },
    paidAt:      { type: Date },
    appealedAt:  { type: Date },
  },
  { timestamps: true }
);

ClaimSchema.index({ riderId: 1, status: 1 });
ClaimSchema.index({ policyId: 1 });
ClaimSchema.index({ triggerType: 1, createdAt: -1 });
ClaimSchema.index({ 'deviceFingerprint.hash': 1, riderId: 1 });

export default mongoose.model<IClaim>('Claim', ClaimSchema);
