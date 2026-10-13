export const emptyData = () => ({ vehicles: [], drivers: [], trips: [], finance_accounts: [], finance_entries: [] });
export const TABLES = ['vehicles', 'drivers', 'trips', 'finance_accounts', 'finance_entries'];
export const currency = (v) => '₹' + (Number(v) || 0).toLocaleString('en-IN', { maximumFractionDigits: 2, minimumFractionDigits: 0 });
export const num = (v) => Number(v) || 0;
export const today = () => new Date().toLocaleDateString('en-CA');
export const uid = () => crypto.randomUUID();

// Original uploaded HTML contained demonstration records. Import only if requested;
// the source's financial figures were hard-coded and are intentionally NOT imported.
export const sampleVehicles = [
  ['KL 10 AB 1234','Tata 407 SFC','2022','Adhil Javad','₹35 / KM','Active'],
  ['KL 10 CD 5678','Eicher Pro 1095','2021','Ameen Asjad','₹38 / KM','Active'],
  ['KL 10 EF 9012','Mazda T3500','2020','Shiyas','30% Gross','Active'],
  ['KL 10 GH 3456','Mahindra Bolero Maxi','2023','Abdul Gani','₹28 / KM','Active'],
  ['KL 10 IJ 7890','Ashok Leyland Dost+','2022','Anees','₹32 / KM','Active'],
  ['KL 10 MN 4512','Tata Ace Gold','2021','Sadik','₹24 / KM','Active'],
  ['KL 10 PQ 6789','Eicher Pro 2049','2023','Ashraf (Relief)','₹36 / KM','Active'],
  ['KL 10 RS 2345','Tata 407 Pickup','2019','Eeppu (Relief)','₹34 / KM','Active'],
  ['KL 10 TU 8901','Isuzu D-Max Super','2023','Lukuman','₹30 / KM','Active'],
  ['KL 10 VW 4321','BharatBenz 1015R','2022','Rafeek','₹46 / KM','Active'],
  ['KL 10 XY 7654','Force Trax Delivery','2020','Pool Standby','₹26 / KM','Active'],
  ['KL 10 ZA 9876','Tata 709g LPT','2021','Relief Rotating','₹40 / KM','Active'],
  ['KL 10 BC 5432','Ashok Leyland Bada Dost','2024','Scheduled Queue','₹33 / KM','Inactive'],
  ['KL 10 DE 1357','Mahindra Supro Maxi','2022','Unassigned Standby','₹25 / KM','Standby']
].map(([plate,model,year,driver_name,rate,status]) => ({ id:uid(), plate,model,year,driver_name,rate,status }));

export const sampleDrivers = [
  ['Adhil Javad','+91 98471 23456','KL-10-2018-0091','30% Gross Fare'],
  ['Ameen Asjad','+91 94462 87654','KL-10-2020-0043','₹35 / KM'],
  ['Shiyas','+91 98950 12389','KL-10-2017-7711','30% Gross Fare'],
  ['Ashraf','+91 97455 11223','KL-10-2015-8899','₹36 / KM'],
  ['Abdul Gani','+91 98460 55432','KL-10-2016-4392','28% Gross Fare'],
  ['Anees','+91 99471 66789','KL-10-2021-1209','₹32 / KM'],
  ['Rafeek','+91 97472 88910','KL-10-2019-5431','₹46 / KM'],
  ['Eeppu','+91 98951 44556','KL-10-2016-9043','₹34 / KM'],
  ['Sadik','+91 94473 22334','KL-10-2022-8172','30% Gross Fare'],
  ['Lukuman','+91 98465 99887','KL-10-2017-6621','₹30 / KM']
].map(([name,phone,license,rate_model]) => ({ id:uid(), name,phone,license,rate_model,status:'Active',opening_due:0 }));

export const sampleAccounts = [
  { id:uid(),name:'Cash',kind:'Cash',opening_balance:0 },
  { id:uid(),name:'Bank Account',kind:'Bank',opening_balance:0 },
  { id:uid(),name:'UPI',kind:'UPI',opening_balance:0 }
];

export function summarize(data) {
  const { vehicles, drivers, trips, finance_accounts: accounts, finance_entries: entries } = data;
  const paymentsByTrip = {};
  const paymentsByDriver = {};
  const balances = Object.fromEntries(accounts.map(a => [a.id,num(a.opening_balance)]));
  let income=0, expenses=0;
  for (const e of entries) {
    const amount=num(e.amount);
    if (e.kind === 'income') {
      income+=amount; balances[e.account_id] = num(balances[e.account_id])+amount;
      if (e.trip_id) paymentsByTrip[e.trip_id]=(paymentsByTrip[e.trip_id]||0)+amount;
    } else if (e.kind === 'expense') {
      expenses+=amount; balances[e.account_id]=num(balances[e.account_id])-amount;
      if (e.driver_id && e.category==='Driver payout') paymentsByDriver[e.driver_id]=(paymentsByDriver[e.driver_id]||0)+amount;
    } else if (e.kind === 'transfer') {
      balances[e.account_id]=num(balances[e.account_id])-amount;
      balances[e.to_account_id]=num(balances[e.to_account_id])+amount;
    }
  }
  const tripDue=(trip)=> Math.max(0,Math.round((num(trip.fare)-num(paymentsByTrip[trip.id]))*100)/100);
  const driverDue=(driver)=> Math.max(0,Math.round((num(driver.opening_due)+trips.filter(t=>t.driver_id===driver.id).reduce((sum,t)=>sum+num(t.driver_share),0)-num(paymentsByDriver[driver.id]))*100)/100);
  const receivable=trips.reduce((sum,t)=>sum+tripDue(t),0);
  const wageDue=drivers.reduce((sum,d)=>sum+driverDue(d),0);
  return { vehicles,drivers,trips,accounts,entries,balances,income,expenses,net:income-expenses,receivable,wageDue,tripDue,driverDue,totalBalance:Object.values(balances).reduce((sum,v)=>sum+num(v),0),pendingTrips:trips.filter(t=>tripDue(t)>0.001).length };
}
