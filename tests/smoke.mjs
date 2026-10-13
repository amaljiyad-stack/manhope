import assert from 'node:assert/strict';
import { emptyData, sampleVehicles, sampleDrivers, sampleAccounts, summarize } from '../src/data.js';

assert.equal(sampleVehicles.length,14,'Original HTML has 14 vehicles');
assert.equal(sampleDrivers.length,10,'Original HTML has 10 drivers');
const state = {...emptyData(),vehicles:sampleVehicles,drivers:sampleDrivers,finance_accounts:sampleAccounts};
const [cash,bank]=sampleAccounts;
const [driver]=sampleDrivers;
const tripId='00000000-0000-4000-8000-000000000001';
state.trips=[{id:tripId, fare:1000,driver_id:driver.id,driver_share:300}];
state.finance_entries=[
  {id:'one',kind:'income',amount:700,account_id:cash.id,trip_id:tripId},
  {id:'two',kind:'expense',amount:100,account_id:cash.id,driver_id:driver.id,category:'Driver payout'},
  {id:'three',kind:'transfer',amount:100,account_id:cash.id,to_account_id:bank.id}
];
const metrics=summarize(state);
assert.equal(metrics.income,700);
assert.equal(metrics.expenses,100);
assert.equal(metrics.net,600);
assert.equal(metrics.tripDue(state.trips[0]),300);
assert.equal(metrics.driverDue(driver),200);
assert.equal(metrics.balances[cash.id],500);
assert.equal(metrics.balances[bank.id],100);
assert.equal(metrics.totalBalance,600);
console.log('PASS: source fleet records, account balances, receipts, payouts and transfers');
