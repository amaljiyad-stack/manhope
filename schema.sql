-- MANHOPE MOBILITY - Supabase SQL Editor: run once in a new project.
-- Auth is managed by Supabase Auth (email/password); each user's data is private.
-- Neither the anon/public key nor this schema bypasses row-level security.
create extension if not exists pgcrypto;

create table if not exists public.vehicles (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 plate text not null check(length(trim(plate)) between 3 and 35),
 model text not null default '',
 year text not null default '',
 driver_name text not null default '',
 rate text not null default '',
 status text not null default 'Active' check(status in ('Active','Standby','Inactive')),
 created_at timestamptz not null default now(),
 unique(owner_id,plate)
);
create table if not exists public.drivers (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null check(length(trim(name)) > 0),
 phone text not null default '',
 license text not null default '',
 rate_model text not null default '',
 status text not null default 'Active' check(status in ('Active','Inactive')),
 opening_due numeric(14,2) not null default 0 check(opening_due >= 0),
 created_at timestamptz not null default now()
);
create table if not exists public.finance_accounts (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null check(length(trim(name))>0),
 kind text not null default 'Bank' check(kind in ('Cash','Bank','UPI','Other')),
 opening_balance numeric(14,2) not null default 0,
 created_at timestamptz not null default now(),
 unique(owner_id,name)
);
create table if not exists public.trips (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 code text not null check(length(trim(code))>0),
 trip_date date not null default current_date,
 vehicle_id uuid references public.vehicles(id) on delete set null,
 vehicle_plate text not null default '',
 driver_id uuid references public.drivers(id) on delete set null,
 driver_name text not null default '',
 client text not null check(length(trim(client))>0),
 origin text not null default '',
 destination text not null default '',
 distance_km numeric(12,2) not null default 0 check(distance_km >= 0),
 fare numeric(14,2) not null check(fare >= 0),
 driver_share numeric(14,2) not null default 0 check(driver_share >= 0),
 cargo text not null default '',
 created_at timestamptz not null default now(),
 unique(owner_id,code)
);
create table if not exists public.finance_entries (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 entry_date date not null default current_date,
 kind text not null check(kind in ('income','expense','transfer')),
 amount numeric(14,2) not null check(amount > 0),
 account_id uuid not null references public.finance_accounts(id) on delete restrict,
 to_account_id uuid references public.finance_accounts(id) on delete restrict,
 category text not null default 'Other',
 description text not null default '',
 trip_id uuid references public.trips(id) on delete set null,
 driver_id uuid references public.drivers(id) on delete set null,
 created_at timestamptz not null default now(),
 constraint proper_transfer check ((kind='transfer' and to_account_id is not null and to_account_id<>account_id and trip_id is null and driver_id is null) or (kind<>'transfer' and to_account_id is null)),
 constraint matching_links check (not (trip_id is not null and kind<>'income') and not(driver_id is not null and (kind<>'expense' or category<>'Driver payout')))
);

create index if not exists vehicles_owner on public.vehicles(owner_id);
create index if not exists drivers_owner on public.drivers(owner_id);
create index if not exists accounts_owner on public.finance_accounts(owner_id);
create index if not exists trips_owner on public.trips(owner_id,trip_date desc);
create index if not exists entries_owner on public.finance_entries(owner_id,entry_date desc);

alter table public.vehicles enable row level security;
alter table public.drivers enable row level security;
alter table public.trips enable row level security;
alter table public.finance_accounts enable row level security;
alter table public.finance_entries enable row level security;

-- Owner-only CRUD for every row, including UPDATE/INSERT check.
drop policy if exists "own vehicles" on public.vehicles;
create policy "own vehicles" on public.vehicles for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
drop policy if exists "own drivers" on public.drivers;
create policy "own drivers" on public.drivers for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
drop policy if exists "own trips" on public.trips;
create policy "own trips" on public.trips for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
drop policy if exists "own accounts" on public.finance_accounts;
create policy "own accounts" on public.finance_accounts for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
drop policy if exists "own entries" on public.finance_entries;
create policy "own entries" on public.finance_entries for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

-- Cross-table links must belong to the very same signed-in user.
create or replace function public.assert_manhope_links() returns trigger
language plpgsql set search_path = '' as $$
begin
 if tg_table_name = 'trips' then
   if new.vehicle_id is not null and not exists(select 1 from public.vehicles where id=new.vehicle_id and owner_id=new.owner_id) then raise exception 'Vehicle belongs to a different workspace'; end if;
   if new.driver_id is not null and not exists(select 1 from public.drivers where id=new.driver_id and owner_id=new.owner_id) then raise exception 'Driver belongs to a different workspace'; end if;
 elsif tg_table_name = 'finance_entries' then
   if not exists(select 1 from public.finance_accounts where id=new.account_id and owner_id=new.owner_id) then raise exception 'Financial account belongs to a different workspace'; end if;
   if new.to_account_id is not null and not exists(select 1 from public.finance_accounts where id=new.to_account_id and owner_id=new.owner_id) then raise exception 'Destination account belongs to a different workspace'; end if;
   if new.trip_id is not null and not exists(select 1 from public.trips where id=new.trip_id and owner_id=new.owner_id) then raise exception 'Trip belongs to a different workspace'; end if;
   if new.driver_id is not null and not exists(select 1 from public.drivers where id=new.driver_id and owner_id=new.owner_id) then raise exception 'Driver belongs to a different workspace'; end if;
 end if;
 return new;
end $$;
drop trigger if exists check_manhope_trip on public.trips;
create trigger check_manhope_trip before insert or update on public.trips for each row execute function public.assert_manhope_links();
drop trigger if exists check_manhope_entry on public.finance_entries;
create trigger check_manhope_entry before insert or update on public.finance_entries for each row execute function public.assert_manhope_links();

-- Calls below are atomic: errors roll the full change back.
create or replace function public.erase_my_data() returns void
language plpgsql security invoker set search_path = '' as $$
begin
 if (select auth.uid()) is null then raise exception 'Sign in required'; end if;
 delete from public.finance_entries where owner_id=auth.uid();
 delete from public.trips where owner_id=auth.uid();
 delete from public.vehicles where owner_id=auth.uid();
 delete from public.drivers where owner_id=auth.uid();
 delete from public.finance_accounts where owner_id=auth.uid();
end $$;

create or replace function public.restore_my_backup(p_backup jsonb) returns void
language plpgsql security invoker set search_path = '' as $$
declare payload jsonb;
begin
 if (select auth.uid()) is null then raise exception 'Sign in required'; end if;
 if coalesce(p_backup->>'version','') <> '1' or coalesce(jsonb_typeof(p_backup->'data'),'') <> 'object' then raise exception 'Invalid backup format'; end if;
 payload := p_backup->'data';
 if jsonb_typeof(payload->'vehicles') <> 'array' or jsonb_typeof(payload->'drivers') <> 'array'
    or jsonb_typeof(payload->'trips') <> 'array' or jsonb_typeof(payload->'finance_accounts') <> 'array'
    or jsonb_typeof(payload->'finance_entries') <> 'array' then raise exception 'Missing backup collections'; end if;
 if jsonb_array_length(payload->'vehicles')>20000 or jsonb_array_length(payload->'drivers')>20000
    or jsonb_array_length(payload->'trips')>20000 or jsonb_array_length(payload->'finance_accounts')>20000
    or jsonb_array_length(payload->'finance_entries')>20000 then raise exception 'Backup exceeds size limit'; end if;
 perform public.erase_my_data();
 insert into public.vehicles (id,owner_id,plate,model,year,driver_name,rate,status)
 select coalesce(r.id,gen_random_uuid()),auth.uid(),r.plate,coalesce(r.model,''),coalesce(r.year,''),coalesce(r.driver_name,''),coalesce(r.rate,''),coalesce(r.status,'Active')
 from jsonb_to_recordset(payload->'vehicles') as r(id uuid,plate text,model text,year text,driver_name text,rate text,status text);
 insert into public.drivers (id,owner_id,name,phone,license,rate_model,status,opening_due)
 select coalesce(r.id,gen_random_uuid()),auth.uid(),r.name,coalesce(r.phone,''),coalesce(r.license,''),coalesce(r.rate_model,''),coalesce(r.status,'Active'),coalesce(r.opening_due,0)
 from jsonb_to_recordset(payload->'drivers') as r(id uuid,name text,phone text,license text,rate_model text,status text,opening_due numeric);
 insert into public.finance_accounts (id,owner_id,name,kind,opening_balance)
 select coalesce(r.id,gen_random_uuid()),auth.uid(),r.name,coalesce(r.kind,'Bank'),coalesce(r.opening_balance,0)
 from jsonb_to_recordset(payload->'finance_accounts') as r(id uuid,name text,kind text,opening_balance numeric);
 insert into public.trips (id,owner_id,code,trip_date,vehicle_id,vehicle_plate,driver_id,driver_name,client,origin,destination,distance_km,fare,driver_share,cargo)
 select coalesce(r.id,gen_random_uuid()),auth.uid(),r.code,coalesce(r.trip_date,current_date),r.vehicle_id,coalesce(r.vehicle_plate,''),r.driver_id,coalesce(r.driver_name,''),r.client,coalesce(r.origin,''),coalesce(r.destination,''),coalesce(r.distance_km,0),r.fare,coalesce(r.driver_share,0),coalesce(r.cargo,'')
 from jsonb_to_recordset(payload->'trips') as r(id uuid,code text,trip_date date,vehicle_id uuid,vehicle_plate text,driver_id uuid,driver_name text,client text,origin text,destination text,distance_km numeric,fare numeric,driver_share numeric,cargo text);
 insert into public.finance_entries (id,owner_id,entry_date,kind,amount,account_id,to_account_id,category,description,trip_id,driver_id)
 select coalesce(r.id,gen_random_uuid()),auth.uid(),coalesce(r.entry_date,current_date),r.kind,r.amount,r.account_id,r.to_account_id,coalesce(r.category,'Other'),coalesce(r.description,''),r.trip_id,r.driver_id
 from jsonb_to_recordset(payload->'finance_entries') as r(id uuid,entry_date date,kind text,amount numeric,account_id uuid,to_account_id uuid,category text,description text,trip_id uuid,driver_id uuid);
end $$;

create or replace function public.import_original_fleet(p_vehicles jsonb,p_drivers jsonb,p_accounts jsonb)
returns void language plpgsql security invoker set search_path = '' as $$
begin
 if (select auth.uid()) is null then raise exception 'Sign in required'; end if;
 if exists(select 1 from public.vehicles where owner_id=auth.uid()) then raise exception 'Only import into an empty fleet'; end if;
 if jsonb_typeof(p_vehicles)<>'array' or jsonb_typeof(p_drivers)<>'array' or jsonb_typeof(p_accounts)<>'array' then raise exception 'Invalid import collections'; end if;
 if jsonb_array_length(p_vehicles)>100 or jsonb_array_length(p_drivers)>100 or jsonb_array_length(p_accounts)>20 then raise exception 'Too many import records'; end if;
 insert into public.vehicles (id,owner_id,plate,model,year,driver_name,rate,status)
 select coalesce(r.id,gen_random_uuid()),auth.uid(),r.plate,coalesce(r.model,''),coalesce(r.year,''),coalesce(r.driver_name,''),coalesce(r.rate,''),coalesce(r.status,'Active')
 from jsonb_to_recordset(p_vehicles) as r(id uuid,plate text,model text,year text,driver_name text,rate text,status text);
 insert into public.drivers (id,owner_id,name,phone,license,rate_model,status,opening_due)
 select coalesce(r.id,gen_random_uuid()),auth.uid(),r.name,coalesce(r.phone,''),coalesce(r.license,''),coalesce(r.rate_model,''),coalesce(r.status,'Active'),coalesce(r.opening_due,0)
 from jsonb_to_recordset(p_drivers) as r(id uuid,name text,phone text,license text,rate_model text,status text,opening_due numeric);
 insert into public.finance_accounts (id,owner_id,name,kind,opening_balance)
 select coalesce(r.id,gen_random_uuid()),auth.uid(),r.name,coalesce(r.kind,'Bank'),coalesce(r.opening_balance,0)
 from jsonb_to_recordset(p_accounts) as r(id uuid,name text,kind text,opening_balance numeric);
end $$;

revoke all on function public.erase_my_data() from public;
revoke all on function public.restore_my_backup(jsonb) from public;
revoke all on function public.import_original_fleet(jsonb,jsonb,jsonb) from public;
grant execute on function public.erase_my_data() to authenticated;
grant execute on function public.restore_my_backup(jsonb) to authenticated;
grant execute on function public.import_original_fleet(jsonb,jsonb,jsonb) to authenticated;

-- Explicit permissions; RLS policies still restrict every row to its owner.
grant usage on schema public to authenticated;
grant select,insert,update,delete on public.vehicles,public.drivers,public.trips,public.finance_accounts,public.finance_entries to authenticated;
