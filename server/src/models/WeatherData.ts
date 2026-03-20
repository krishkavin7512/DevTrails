import mongoose, { Schema, Document } from 'mongoose';

export interface IWeatherData extends Document {
  city: string;
  pincode: string;
  dataType: 'Weather' | 'AQI' | 'Flood' | 'Social';
  data: {
    temperature: number;
    feelsLike: number;
    humidity: number;
    rainfall: number;
    windSpeed: number;
    aqi: number;
    pm25: number;
    pm10: number;
    weatherCondition: string;
    description: string;
  };
  isDisruptionActive: boolean;
  disruptionSeverity: 'None' | 'Mild' | 'Moderate' | 'Severe' | 'Extreme';
  fetchedAt: Date;
  source: string;
}

const WeatherDataSchema = new Schema<IWeatherData>(
  {
    city: { type: String, required: true },
    pincode: { type: String, required: true },
    dataType: { type: String, required: true, enum: ['Weather', 'AQI', 'Flood', 'Social'] },
    data: {
      temperature: { type: Number, default: 0 },
      feelsLike: { type: Number, default: 0 },
      humidity: { type: Number, default: 0 },
      rainfall: { type: Number, default: 0 },
      windSpeed: { type: Number, default: 0 },
      aqi: { type: Number, default: 0 },
      pm25: { type: Number, default: 0 },
      pm10: { type: Number, default: 0 },
      weatherCondition: { type: String, default: 'Clear' },
      description: { type: String, default: '' },
    },
    isDisruptionActive: { type: Boolean, default: false },
    disruptionSeverity: {
      type: String,
      enum: ['None', 'Mild', 'Moderate', 'Severe', 'Extreme'],
      default: 'None',
    },
    fetchedAt: { type: Date, default: Date.now },
    source: { type: String, required: true },
  },
  { timestamps: true }
);

WeatherDataSchema.index({ city: 1, dataType: 1, fetchedAt: -1 });
WeatherDataSchema.index({ pincode: 1, fetchedAt: -1 });
WeatherDataSchema.index({ isDisruptionActive: 1 });

export default mongoose.model<IWeatherData>('WeatherData', WeatherDataSchema);
