import type { Metadata } from 'next';
import { DM_Sans } from 'next/font/google';
import { Toaster } from 'react-hot-toast';
import './globals.css';

const dmSans = DM_Sans({
  variable: '--font-dm-sans',
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'RainCheck — Income Protection for Delivery Partners',
  description:
    'AI-powered parametric insurance that pays you automatically when weather, pollution, or disruptions stop you from earning. No paperwork. Instant payouts.',
  keywords: ['insurance', 'gig workers', 'food delivery', 'parametric', 'raincheck', 'zomato', 'swiggy'],
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" data-scroll-behavior="smooth" className={`${dmSans.variable} h-full`}>
      <head>
        <link rel="preconnect" href="https://api.fontshare.com" />
        <link
          href="https://api.fontshare.com/v2/css?f[]=satoshi@400,500,600,700&display=swap"
          rel="stylesheet"
        />
      </head>
      <body className="min-h-full flex flex-col antialiased bg-dark text-gray-100">
        {children}
        <Toaster
          position="top-right"
          toastOptions={{
            style: {
              background: '#1F2937',
              color: '#F9FAFB',
              border: '1px solid rgba(255,255,255,0.08)',
              borderRadius: '12px',
              fontSize: '14px',
            },
            success: { iconTheme: { primary: '#10b981', secondary: '#022c22' } },
            error: { iconTheme: { primary: '#ef4444', secondary: '#450a0a' } },
          }}
        />
      </body>
    </html>
  );
}
