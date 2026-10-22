# CampusFind - Campus Lost and Found Portal

A GitHub-ready **Next.js + Supabase + Vercel** full-stack project for a GTU Design Engineering submission.

**Project:** Campus Lost and Found Portal  
**Enrollment No.:** 221173107008

## Implemented features
- Responsive landing page with live report statistics
- Email registration, email confirmation and login via Supabase Auth
- Lost and found reports (location, date, category, description and optional image)
- Public search and category/type filters
- Student dashboard and personal report history
- Found-item ownership claims with private identifying details
- Claim status and staff-only review
- Admin dashboard: approve/reject claims; approved claims mark items returned
- Supabase PostgreSQL, RLS policies, storage restrictions, atomic admin review RPC

## 1. Prerequisites
- Node.js 20.9+ (22 LTS recommended)
- A free Supabase project at https://supabase.com
- A GitHub repository and a Vercel account

## 2. Database
1. Supabase Dashboard > **SQL Editor** > New query.
2. Paste and **Run** all of `supabase/schema.sql` on a NEW Supabase project.
3. Supabase > Authentication > Providers > Email: enable email. For real student accounts, keep email confirmation enabled and configure email delivery.
4. In Supabase > Authentication > URL Configuration set Site URL to your production `https://your-app.vercel.app` and include that URL in Redirect URLs. Add `http://localhost:3000` for development.
5. Supabase > Settings / Connect > retrieve **Project URL** and **publishable/anon** key. Never use a secret/service-role key in client environment variables.

## 3. Local run
```bash
npm install
cp .env.example .env.local
# Edit .env.local with Supabase URL and publishable / anon key
npm run dev
```
Open http://localhost:3000 .

Windows PowerShell environment file copy: `Copy-Item .env.example .env.local`.

## 4. Administrator account setup (controlled)
1. Open the running website. Register your real administrative email/password.
2. Confirm your email and sign in once.
3. In Supabase SQL Editor, run the following with your real admin email **only after confirming the account is yours**:
```sql
update public.profiles
set role = 'admin'
where id = (select id from auth.users where email = 'ADMIN_EMAIL_HERE');
```
4. Sign out and sign in again. An **Admin** tab appears.
5. Do not build a public admin signup form and do not update `role` from the browser.

## 5. GitHub upload
- Create a new repository (do not add README if you plan to push this directory as-is).
- From the unzipped project folder:
```bash
git init
git add .
git commit -m "Initial CampusFind portal"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```
Alternatively use GitHub's **Add file > Upload files** and upload the unzipped folders. Do NOT upload `.env.local` or `node_modules`.

## 6. Deploy on Vercel
1. Vercel > Add New > Project > Import Git Repository.
2. Framework preset should be detected as **Next.js**.
3. In **Environment Variables**, add:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
4. Deploy. Add the production URL to Supabase Authentication URL Configuration and redeploy after any variable changes.
5. Test registration/confirmation, report creation, image upload, search, claim submission, review, and logout.

## Project pages
The application uses a single responsive application shell with navigation between Home, Browse Items, Report Item, My Dashboard, My Claims and Admin. These are live views backed by Supabase; they are not static mockups.

## Design notes and limitations
- **Email verification** depends on Supabase Auth email settings and deliverability.
- **Public reports/photos**: Never upload full ID card numbers, banking information, access credentials, or item secrets. Review reports manually before using this at a real college. A public submission moderation workflow is a future enhancement.
- Student item reports are immutable after creation in this version. Contact an administrator to correct inaccurate reports.
- The current application supports English UI and does not yet send match notifications or implement AI matching.
- `admin` is granted manually through SQL; do not use an account/email you don't control.
- `item-images` uses a publicly readable Supabase Storage bucket; images must be safe for public display.
- This app is suitable for a GTU prototype and should undergo security testing and institutional review before production use with real sensitive student data.

## Manual testing plan
1. Create Student A and Student B, verify email and sign in.
2. A reports a found water bottle; B can see it in Browse.
3. B submits private ownership proof; claim appears as pending.
4. Student B cannot access the Admin screen or view Student A's data as an administrator.
5. Sign in with authorized admin; approve claim; item changes to Returned; claim becomes Approved.
6. Search and filters work; photos load; sign out and sign in persist correctly.
7. Test responsive screens and invalid images, filenames, blank forms, and duplicate claims.

**Note:** These are test steps to run after deployment, not claims that they have already passed.
