import { createClient } from '@supabase/supabase-js';
import { emptyData, TABLES, sampleVehicles, sampleDrivers, sampleAccounts, uid } from './data';

const url = import.meta.env.VITE_SUPABASE_URL;
const anon = import.meta.env.VITE_SUPABASE_ANON_KEY;
export const cloudEnabled = Boolean(url && anon && /^https:\/\//.test(url) && !url.includes('YOUR-PROJECT') && !anon.includes('YOUR_'));
export const supabase = cloudEnabled ? createClient(url,anon,{auth:{autoRefreshToken:true,persistSession:true,detectSessionInUrl:true}}) : null;
const LOCAL_KEY='manhope_mobility_v1';

const clean = (v) => JSON.parse(JSON.stringify(v));
export function getLocal() {
  try {
    const saved=JSON.parse(localStorage.getItem(LOCAL_KEY));
    if(saved && TABLES.every(t=>Array.isArray(saved[t]))) return saved;
  } catch (_) { /* Fresh workspace if existing data is damaged. */ }
  const first = { ...emptyData(), vehicles: clean(sampleVehicles), drivers: clean(sampleDrivers), finance_accounts:clean(sampleAccounts) };
  localStorage.setItem(LOCAL_KEY,JSON.stringify(first));
  return first;
}
export function setLocal(state) {
  try { localStorage.setItem(LOCAL_KEY,JSON.stringify(state)); }
  catch (error) { throw new Error('Unable to save in this browser. Check storage permissions or free space. '+error.message); }
  return state;
}

export function validateBackup(raw) {
  if(!raw || typeof raw !== 'object' || raw.version!==1 || !raw.data || typeof raw.data!=='object') throw Error('This is not a Manhope version 1 backup.');
  for(const table of TABLES) {
    if(!Array.isArray(raw.data[table]) || raw.data[table].length>20000) throw Error('Invalid or oversized backup: '+table);
    if(raw.data[table].some(row=> !row || typeof row !=='object' || Array.isArray(row))) throw Error('Invalid rows in '+table);
  }
  return Object.fromEntries(TABLES.map(t=>[t,raw.data[t]]));
}
export function createBackup(data) { return {app:'Manhope Mobility',version:1,exported_at:new Date().toISOString(),data:clean(data)}; }

// All tables use strict owner-scoped RLS in Supabase. Never put the service-role key in this app.
export async function loadCloud() {
  const results=await Promise.all(TABLES.map(async table=>{
    const {data,error}=await supabase.from(table).select('*').order('created_at',{ascending:false});
    if(error) throw Error(`Loading ${table}: ${error.message}`);
    return [table,data||[]];
  }));
  return Object.fromEntries(results);
}
export async function writeCloud(table,verb,payload) {
  if(!TABLES.includes(table)) throw Error('Unknown data table.');
  let response;
  if(verb==='create') response=await supabase.from(table).insert(payload);
  else if(verb==='update') {
    const {id,...changes}=payload;
    response=await supabase.from(table).update(changes).eq('id',id);
  } else if(verb==='delete') response=await supabase.from(table).delete().eq('id',payload);
  else throw Error('Unknown data operation.');
  if(response.error) throw Error(response.error.message);
}
export async function writeLocal(table,verb,payload) {
  const old=getLocal();
  if(!TABLES.includes(table)) throw Error('Unknown data table.');
  let rows=old[table];
  if(verb==='create') rows=[...(Array.isArray(payload)?payload:[payload]).map(row=>({...row,id:row.id||uid(),created_at:new Date().toISOString()})),...rows];
  else if(verb==='update') rows=rows.map(row=>row.id===payload.id?{...row,...payload}:row);
  else if(verb==='delete') rows=rows.filter(row=>row.id!==payload);
  else throw Error('Unknown data operation.');
  // Match database ON DELETE SET NULL for linked trips/entries.
  const next={...old,[table]:rows};
  if(verb==='delete' && table==='trips') next.finance_entries=old.finance_entries.map(e=>e.trip_id===payload?{...e,trip_id:null}:e);
  if(verb==='delete' && table==='drivers') {
    next.trips=old.trips.map(t=>t.driver_id===payload?{...t,driver_id:null}:t);
    next.finance_entries=old.finance_entries.map(e=>e.driver_id===payload?{...e,driver_id:null}:e);
  }
  if(verb==='delete' && table==='vehicles') next.trips=old.trips.map(t=>t.vehicle_id===payload?{...t,vehicle_id:null}:t);
  if(verb==='delete' && table==='finance_accounts' && old.finance_entries.some(e=>e.account_id===payload||e.to_account_id===payload)) throw Error('This account has ledger records. Delete or move those records before deleting it.');
  return setLocal(next);
}
export async function clearAll() {
  if(cloudEnabled){ const {error}=await supabase.rpc('erase_my_data'); if(error) throw Error(error.message); }
  else setLocal(emptyData());
}
export async function restoreAll(data) {
  if(cloudEnabled){
    const {error}=await supabase.rpc('restore_my_backup',{p_backup:{version:1,data}});
    if(error) throw Error(error.message);
  } else setLocal(clean(data));
}
export async function importOriginalFleet(current) {
  if(current.vehicles.length) throw Error('Import into an empty vehicle registry only.');
  if(cloudEnabled) {
    // Use a single database transaction so imports cannot be left half-completed.
    const {error}=await supabase.rpc('import_original_fleet',{
      p_vehicles:sampleVehicles,
      p_drivers:current.drivers.length?[]:sampleDrivers,
      p_accounts:current.finance_accounts.length?[]:sampleAccounts
    });
    if(error) throw Error(error.message);
  } else {
    setLocal({...current,vehicles:clean(sampleVehicles),drivers:current.drivers.length?current.drivers:clean(sampleDrivers),finance_accounts:current.finance_accounts.length?current.finance_accounts:clean(sampleAccounts)});
  }
}
