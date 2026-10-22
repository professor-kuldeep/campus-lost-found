import { createClient, type SupabaseClient } from '@supabase/supabase-js';
let singleton: SupabaseClient | null = null;
export function getSupabase(): SupabaseClient | null {
  if (singleton) return singleton;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) return null;
  singleton = createClient(url, key, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } });
  return singleton;
}
export type Item = {
 id:string; user_id:string; title:string; item_type:'lost'|'found'; category:string;
 description:string; location:string; incident_date:string; image_path:string|null;
 status:'lost'|'found'|'claim_pending'|'returned'|'closed'; created_at:string;
};
export type Claim = { id:string; item_id:string; claimant_id:string; proof_description:string;
 status:'pending'|'approved'|'rejected'; created_at:string; items?: {title:string,location:string} | null; };
export const categories=['ID Card','Wallet','Keys','Phone','Laptop','Earphones','Books','Bag','Bottle','Other'];
export const locations=['Library','Canteen','Classroom','Laboratory','Auditorium','Parking Area','Sports Ground','Corridor','Office','Other'];
