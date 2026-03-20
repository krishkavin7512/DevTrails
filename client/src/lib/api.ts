import axios from 'axios';

const SERVER_URL = process.env.NEXT_PUBLIC_SERVER_URL || 'http://localhost:5001';
const ML_URL = process.env.NEXT_PUBLIC_ML_URL || 'http://localhost:8000';

export const api = axios.create({
  baseURL: `${SERVER_URL}/api`,
  timeout: 10000,
  headers: { 'Content-Type': 'application/json' },
});

export const mlApi = axios.create({
  baseURL: `${ML_URL}/api/ml`,
  timeout: 15000,
  headers: { 'Content-Type': 'application/json' },
});

// Unwrap the { success, data } envelope
api.interceptors.response.use(
  (res) => res.data,
  (err) => Promise.reject(new Error(err.response?.data?.error || err.message || 'Request failed'))
);

mlApi.interceptors.response.use(
  (res) => res.data,
  (err) => Promise.reject(new Error(err.response?.data?.error || err.message || 'ML service unavailable'))
);
