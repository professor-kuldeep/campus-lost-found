import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title:'CampusFind | Lost & Found Portal', description:'A secure campus lost and found reporting and recovery portal.' };
export default function RootLayout({children}:{children:React.ReactNode}) { return <html lang="en"><body>{children}</body></html> }
