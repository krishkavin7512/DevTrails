import mongoose from 'mongoose';

const MAX_RETRIES = 5;
const RETRY_DELAY_MS = 2000;

export const connectDB = async (): Promise<void> => {
  const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/raincheck';
  let retries = 0;

  mongoose.connection.on('connected', () => console.log('✅ MongoDB connected'));
  mongoose.connection.on('error', (err) => console.error('❌ MongoDB error:', err.message));
  mongoose.connection.on('disconnected', () => console.warn('⚠️  MongoDB disconnected'));

  while (retries < MAX_RETRIES) {
    try {
      await mongoose.connect(uri, { serverSelectionTimeoutMS: 5000 });
      return;
    } catch (err) {
      retries++;
      console.error(`MongoDB connection attempt ${retries}/${MAX_RETRIES} failed`);
      if (retries < MAX_RETRIES) {
        await new Promise(r => setTimeout(r, RETRY_DELAY_MS * retries));
      }
    }
  }
  throw new Error('Could not connect to MongoDB after maximum retries');
};

export const disconnectDB = async (): Promise<void> => {
  await mongoose.disconnect();
};
