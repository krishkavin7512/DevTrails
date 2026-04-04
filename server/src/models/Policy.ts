import mongoose, { Schema, Document } from 'mongoose';

export interface IPolicy extends Document {
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
  graceEndsAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const PolicySchema = new Schema<IPolicy>(
  {
    riderId: { type: Schema.Types.ObjectId, ref: 'Rider', required: true },
    planType: { type: String, required: true, enum: ['Basic', 'Standard', 'Premium'] },
    weeklyPremium: { type: Number, required: true, min: 2900 },
    coverageLimit: { type: Number, required: true },
    coveredDisruptions: [{ type: String }],
    status: {
      type: String,
      required: true,
      enum: ['Active', 'Expired', 'Cancelled', 'PendingPayment'],
      default: 'PendingPayment',
    },
    startDate: { type: Date, required: true },
    endDate: { type: Date, required: true },
    autoRenew: { type: Boolean, default: true },
    policyNumber: { type: String, required: true, unique: true },
    renewalCount: { type: Number, default: 0 },
    graceEndsAt:  { type: Date },
  },
  { timestamps: true }
);

PolicySchema.index({ riderId: 1, status: 1 });
PolicySchema.index({ endDate: 1, autoRenew: 1 });

export default mongoose.model<IPolicy>('Policy', PolicySchema);
