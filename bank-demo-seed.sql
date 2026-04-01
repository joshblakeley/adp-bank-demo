-- Bank Demo Seed Script
-- Creates schema and populates mock data for ADP conference demo

-- Schema
CREATE TABLE IF NOT EXISTS customers (
  id    SERIAL PRIMARY KEY,
  name  TEXT NOT NULL,
  email TEXT,
  phone TEXT
);

CREATE TABLE IF NOT EXISTS accounts (
  id              SERIAL PRIMARY KEY,
  customer_id     INTEGER REFERENCES customers(id),
  type            TEXT NOT NULL,
  balance         NUMERIC(12,2) NOT NULL,
  overdraft_limit NUMERIC(12,2) DEFAULT 0
);

CREATE TABLE IF NOT EXISTS transactions (
  id          SERIAL PRIMARY KEY,
  account_id  INTEGER REFERENCES accounts(id),
  amount      NUMERIC(12,2) NOT NULL,
  description TEXT,
  ts          TIMESTAMPTZ NOT NULL
);

-- Customers
INSERT INTO customers (name, email, phone) VALUES
  ('Alice Johnson',   'alice.johnson@email.com',   '614-555-0101'),
  ('Bob Martinez',    'bob.martinez@email.com',     '614-555-0102'),
  ('Sarah Miller',    'sarah.miller@email.com',     '614-555-0103'),
  ('James Chen',      'james.chen@email.com',       '614-555-0104'),
  ('Emily Davis',     'emily.davis@email.com',      '614-555-0105'),
  ('Michael Brown',   'michael.brown@email.com',    '614-555-0106'),
  ('Linda Wilson',    'linda.wilson@email.com',     '614-555-0107'),
  ('David Taylor',    'david.taylor@email.com',     '614-555-0108'),
  ('Karen Anderson',  'karen.anderson@email.com',   '614-555-0109'),
  ('Tom Garcia',      'tom.garcia@email.com',       '614-555-0110');

-- Accounts (customer_id matches insert order above)
INSERT INTO accounts (customer_id, type, balance, overdraft_limit) VALUES
  (1,  'checking', 4823.50,   500.00),   -- Alice: healthy checking
  (1,  'savings',  12400.00,    0.00),   -- Alice: healthy savings
  (2,  'checking',   -87.42,  250.00),   -- Bob: overdrawn but within limit
  (2,  'savings',   310.00,     0.00),   -- Bob: low savings
  (3,  'checking',  -412.88,  300.00),   -- Sarah: overdraft_exceeded
  (3,  'savings',  1800.00,     0.00),   -- Sarah: healthy savings
  (4,  'checking',   742.15,  500.00),   -- James: healthy
  (5,  'checking',    42.30,  200.00),   -- Emily: low
  (5,  'savings',  6200.00,     0.00),   -- Emily: healthy savings
  (6,  'checking', -195.00,   500.00),   -- Michael: overdrawn within limit
  (7,  'checking', 1540.00,   500.00),   -- Linda: healthy
  (8,  'checking',    18.75,  100.00),   -- David: low
  (9,  'checking', 9300.00,  1000.00),   -- Karen: healthy
  (10, 'checking',  -22.10,   200.00);   -- Tom: overdrawn within limit

-- Transactions (last ~30 days of activity)
-- Alice checking (account 1) - stable, regular spending
INSERT INTO transactions (account_id, amount, description, ts) VALUES
  (1,  3200.00, 'Direct deposit - Payroll',        NOW() - INTERVAL '28 days'),
  (1,  -120.00, 'Whole Foods Market',               NOW() - INTERVAL '25 days'),
  (1,  -850.00, 'Rent payment',                     NOW() - INTERVAL '22 days'),
  (1,   -45.60, 'BP Gas Station',                   NOW() - INTERVAL '20 days'),
  (1,  -200.00, 'Transfer to savings',              NOW() - INTERVAL '18 days'),
  (1,   -89.99, 'Amazon.com',                       NOW() - INTERVAL '14 days'),
  (1,   -55.00, 'Ohio Edison - Utility',            NOW() - INTERVAL '10 days'),
  (1,  3200.00, 'Direct deposit - Payroll',         NOW() - INTERVAL '1 day');

-- Bob checking (account 3) - overdrawn, recent large debits
INSERT INTO transactions (account_id, amount, description, ts) VALUES
  (3,  1800.00, 'Direct deposit - Payroll',         NOW() - INTERVAL '30 days'),
  (3,  -950.00, 'Rent payment',                     NOW() - INTERVAL '28 days'),
  (3,  -210.00, 'Car payment - Honda Finance',      NOW() - INTERVAL '20 days'),
  (3,  -180.42, 'Kroger Grocery',                   NOW() - INTERVAL '15 days'),
  (3,  -320.00, 'Dentist - Columbus Dental',        NOW() - INTERVAL '10 days'),
  (3,   -89.00, 'Netflix / Spotify / subscriptions',NOW() - INTERVAL '7 days'),
  (3,  -138.00, 'Target',                           NOW() - INTERVAL '3 days');

-- Sarah checking (account 5) - overdraft exceeded
INSERT INTO transactions (account_id, amount, description, ts) VALUES
  (5,  2200.00, 'Direct deposit - Payroll',         NOW() - INTERVAL '29 days'),
  (5, -1100.00, 'Rent payment',                     NOW() - INTERVAL '27 days'),
  (5,  -280.00, 'Car insurance - Progressive',      NOW() - INTERVAL '22 days'),
  (5,  -175.00, 'Electricity & Gas',                NOW() - INTERVAL '18 days'),
  (5,  -350.00, 'Car repair - Midas',               NOW() - INTERVAL '12 days'),
  (5,  -195.88, 'Walmart',                          NOW() - INTERVAL '8 days'),
  (5,  -214.00, 'Medical bill - OhioHealth',        NOW() - INTERVAL '4 days'),
  (5,  -300.00, 'Unexpected travel expense',        NOW() - INTERVAL '2 days');

-- Michael checking (account 10) - overdrawn within limit
INSERT INTO transactions (account_id, amount, description, ts) VALUES
  (10, 2500.00, 'Direct deposit - Payroll',         NOW() - INTERVAL '30 days'),
  (10, -1200.00,'Rent payment',                     NOW() - INTERVAL '28 days'),
  (10,  -400.00,'Student loan payment',             NOW() - INTERVAL '21 days'),
  (10,  -250.00,'Groceries - Trader Joes',          NOW() - INTERVAL '14 days'),
  (10,  -495.00,'Laptop repair',                    NOW() - INTERVAL '9 days'),
  (10,   -75.00,'AT&T phone bill',                  NOW() - INTERVAL '5 days'),
  (10,  -275.00,'Flight - Southwest Airlines',      NOW() - INTERVAL '2 days');

-- Emily checking (account 8) - low balance
INSERT INTO transactions (account_id, amount, description, ts) VALUES
  (8,  1600.00, 'Direct deposit - Payroll',         NOW() - INTERVAL '28 days'),
  (8,   -800.00,'Rent payment',                     NOW() - INTERVAL '26 days'),
  (8,   -320.00,'Car payment',                      NOW() - INTERVAL '19 days'),
  (8,   -150.00,'Groceries',                        NOW() - INTERVAL '13 days'),
  (8,   -180.00,'Utilities',                        NOW() - INTERVAL '8 days'),
  (8,   -107.70,'Various dining',                   NOW() - INTERVAL '3 days');

-- Tom checking (account 14) - overdrawn within limit
INSERT INTO transactions (account_id, amount, description, ts) VALUES
  (14, 1900.00, 'Direct deposit - Payroll',         NOW() - INTERVAL '29 days'),
  (14, -900.00, 'Rent payment',                     NOW() - INTERVAL '27 days'),
  (14, -340.00, 'Car insurance + registration',     NOW() - INTERVAL '20 days'),
  (14, -290.00, 'Groceries & household',            NOW() - INTERVAL '12 days'),
  (14, -195.00, 'Dental emergency',                 NOW() - INTERVAL '6 days'),
  (14, -197.10, 'Home Depot',                       NOW() - INTERVAL '2 days');
