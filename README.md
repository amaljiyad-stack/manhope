# Manhope Mobility — Fleet & Financial Control

A fully editable **Vercel-ready** React/Vite app, rebuilt from the uploaded Manhope Mobility HTML screen. **No vehicle service or repair module** is included. All vehicles are displayed together on one searchable page.

## Features

- **User accounts:** email sign up, login, logout, password reset (via Supabase Auth).
- **True cloud persistence:** create, read, update and permanently delete data, with per-user row-level security.
- **All vehicles on one page:** register, search, edit, change driver assignment, change active/standby/inactive status, delete, CSV export.
- **Drivers:** register, edit, delete, track earned wages and recorded payout history.
- **Dispatches / trips:** register and edit routes/fares, track client payment dues, preserve paid trip history.
- **Financial accounts:** Cash, Bank, UPI and custom; starting balances and calculated live balances.
- **Bookkeeping ledger:** income, expenses, internal transfers, edit/delete transactions, CSV export. Receipts linked to trips reduce outstanding fares; driver payouts linked to drivers reduce wage balances.
- **Safety / backups:** download complete JSON backup, restore JSON, and full irreversible workspace wipe requiring checkbox + `ERASE` confirmation. In cloud mode, restore/wipe are atomic SQL transactions.
- **Original list available:** optional import of 14 example vehicles + 10 drivers from the uploaded HTML; no invented/hard-coded financial figures are seeded.

> The original file was only a UI demonstration. Its home/revenue numbers and several success popups were placeholders, not a saved database. This rebuild derives totals from actual ledger records.

## Step 1 — Create free Supabase project

1. Create a Supabase project at https://supabase.com/dashboard .
2. In **SQL Editor**, open and run the full `supabase/schema.sql` file in this package. This creates tables, owner-only Row Level Security policies, foreign-key checks, and backup/erase functions.
3. In **Authentication > Providers**, ensure **Email** authentication is enabled. You can keep email confirmation ON (recommended). If emails do not arrive, configure Supabase SMTP for production.
4. In **Project Settings > API**, copy the **Project URL** and the **publishable or legacy anon public key** (not the secret or service-role key).
5. In **Authentication > URL Configuration**, add your final `https://YOUR-SITE.vercel.app` under **Site URL** and **Redirect URLs**. This is important for verification and password reset emails. Include localhost `http://localhost:5173` for local testing.

## Step 2 — Deploy on Vercel

### Option A: Deploy from GitHub (simplest ongoing updates)
1. Unzip this folder, push its contents to a GitHub repository.
2. Open https://vercel.com/new , import that repository.
3. Vercel should detect **Vite**. Use `npm run build` and `dist` as output directory (both set in `vercel.json`).
4. Under **Environment Variables**, add:

   - `VITE_SUPABASE_URL` = your Supabase Project URL
   - `VITE_SUPABASE_ANON_KEY` = your Supabase publishable/anon key

5. Deploy. Add the final Vercel domain to Supabase Authentication URL Configuration as described above. Redeploy if you change the environment values.

### Option B: Deploy with Vercel CLI (without GitHub)

Unzip the folder, open a terminal inside `manhope-vercel-app`, and run:

```sh
npm install
npm install -g vercel
vercel login
vercel --prod
```

Set the same environment variables in your Vercel project settings, then redeploy (`vercel --prod`). The zip is a source-project upload, **not** a ready-made single HTML file; Vercel must build it.

## Step 3 — Start using it

- Sign up using your email, confirm if asked, then sign in.
- On **Vehicles**, choose **Import original 14 vehicles** if you want the sample list from the uploaded file, or enter your real vehicles instead. Imported names/plates are **demonstration records** until you verify them.
- On **Accounts → Money accounts**, create or edit your Cash/Bank/UPI account starting balances. (Importing the sample fleet also creates default zero-balance accounts when none exist.)
- Record actual receipts, expenses, transfers, trips and wages. All values update automatically.
- Use **Backup & data tools** before making a major reset.

## Local development

```sh
npm install
cp .env.example .env.local
# replace the .env.local values with your Supabase project URL/key
npm run dev
```

**If Supabase environment variables are absent, the app enters clearly labelled local-preview mode:** it is usable right away with the original 14 vehicle examples, driver examples and starter accounts. Changes are saved only in the same browser (`localStorage`), **not** in an actual login account, and are not synced across users/devices. This mode is for testing, not shared production operations. Configure Supabase before using the software with real financial data.

## Data model / accuracy

- **Financial reporting is cash-basis:** income and expenses are summed from ledger transactions. Transfers do not count as revenue or expense. Starting balances do not count as income.
- **Outstanding client fare:** trip fare minus linked income receipts. Trips remain in history after being fully paid.
- **Driver unpaid wages:** driver's opening due plus assigned trip shares minus linked wage payout expenses. Wage payouts are ledger records; they are **not actual bank/UPI transfers**. Execute the real payment separately with your bank/UPI provider and record it here.
- **Vehicle association:** trips also store plate/driver name snapshots to retain historical details after vehicle/driver deletion.
- **Account deletion:** linked ledger entries must be removed first, to avoid orphan financial records.
- **Workspace isolation:** signed-in users see only their own records. This is individual-account isolation, not multi-user staff invitations/shared-company permissions.
- **Data retention:** deleting a trip/driver/vehicle does not silently delete associated financial entries. Linked pointers are removed; accounting entries are retained until explicitly deleted or wiped.
- **Recovery:** JSON backups are intended for restoring the same workspace. Restoring into a *different existing cloud user* may produce UUID conflicts, since backups preserve record identities.

## Security notes

- Only use the Supabase **anon/publishable key** in a Vite `VITE_*` variable. **Never put the Supabase secret/service-role key in Vercel frontend variables.**
- Every business table has strict `owner_id = auth.uid()` RLS. Direct client reads/writes are restricted to authenticated owner rows.
- This app does not contain invoicing, statutory GST calculations, payment-gateway/bank integrations, or automated reconciliation. Payment buttons only **record a payment you have actually received/sent**.
- Consider regular exports. Browser-local mode has no off-device backup unless you download its JSON backup.

## Useful files

- `src/main.jsx` — screens and interactive operations
- `src/data.js` — imported example fleet and calculation logic
- `src/api.js` — cloud/local persistence and backups
- `src/styles.css` — responsive interface
- `supabase/schema.sql` — required hosted database tables, RLS and server-side atomic reset/restore
- `.env.example` — environment variable names (copy values locally; never commit private `.env.local`)
