import mongoose, { Schema, Document } from 'mongoose';

export interface IDisruptionEvent extends Document {
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
  createdAt: Date;
  updatedAt: Date;
}

const DisruptionEventSchema = new Schema<IDisruptionEvent>(
  {
    city: { type: String, required: true },
    zones: [{ type: String }],
    type: {
      type: String,
      required: true,
      enum: ['HeavyRain', 'ExtremeHeat', 'SevereAQI', 'Flooding', 'SocialDisruption'],
    },
    severity: { type: String, required: true, enum: ['Moderate', 'Severe', 'Extreme'] },
    title: { type: String, required: true },
    description: { type: String, required: true },
    startTime: { type: Date, required: true },
    endTime: { type: Date },
    triggerData: {
      parameter: { type: String, required: true },
      value: { type: Number, required: true },
      threshold: { type: Number, required: true },
    },
    affectedRiders: { type: Number, default: 0 },
    totalPayouts: { type: Number, default: 0 },
    claimsGenerated: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true },
    source: {
      type: String,
      required: true,
      enum: ['Automated', 'AdminTriggered', 'CommunityReport'],
      default: 'Automated',
    },
  },
  { timestamps: true }
);

DisruptionEventSchema.index({ city: 1, type: 1, isActive: 1 });
DisruptionEventSchema.index({ startTime: -1 });
DisruptionEventSchema.index({ isActive: 1 });

export default mongoose.model<IDisruptionEvent>('DisruptionEvent', DisruptionEventSchema);
