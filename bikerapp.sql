-- ============================================================
-- BikerApp PostgreSQL Schema + Seed Data
-- Run: psql -U postgres -d bikerapp -f bikerapp.sql
-- ============================================================

-- Create DB (run separately if needed):
-- CREATE DATABASE bikerapp;

-- ── TABLES ───────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          VARCHAR(100) NOT NULL,
  email         VARCHAR(150) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  phone         VARCHAR(20),
  avatar_url    TEXT,
  bio           TEXT,
  city          VARCHAR(100),
  total_rides   INT DEFAULT 0,
  total_km      NUMERIC(10,2) DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vehicles (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES users(id) ON DELETE CASCADE,
  name       VARCHAR(150) NOT NULL,
  nickname   VARCHAR(100),
  brand      VARCHAR(100),
  model      VARCHAR(100),
  year       INT,
  engine_cc  INT,
  fuel_type  VARCHAR(30) DEFAULT 'Petrol',
  color      VARCHAR(60),
  reg_number VARCHAR(30),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS rides (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name             VARCHAR(200) NOT NULL,
  description      TEXT,
  source           VARCHAR(200) NOT NULL,
  destination      VARCHAR(200) NOT NULL,
  start_date       DATE NOT NULL,
  start_time       TIME NOT NULL,
  end_date         DATE,
  end_time         TIME,
  total_km         NUMERIC(10,2) DEFAULT 0,
  duration         VARCHAR(50),
  cover_photo      TEXT,
  cover_photo_name VARCHAR(100),
  is_public        BOOLEAN DEFAULT TRUE,
  is_paid          BOOLEAN DEFAULT FALSE,
  entry_fee        NUMERIC(10,2) DEFAULT 0,
  max_participants INT DEFAULT 20,
  cloned_count     INT DEFAULT 0,
  status           VARCHAR(30) DEFAULT 'upcoming'
                     CHECK (status IN ('upcoming','active','completed','cancelled')),
  tags             TEXT[] DEFAULT '{}',
  host_id          UUID REFERENCES users(id) ON DELETE SET NULL,
  lead_rider_id    UUID REFERENCES users(id) ON DELETE SET NULL,
  marshal_id       UUID REFERENCES users(id) ON DELETE SET NULL,
  sweep_id         UUID REFERENCES users(id) ON DELETE SET NULL,
  cloned_from      UUID REFERENCES rides(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ride_waypoints (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id    UUID REFERENCES rides(id) ON DELETE CASCADE,
  name       VARCHAR(200) NOT NULL,
  time       VARCHAR(20),
  type       VARCHAR(20) DEFAULT 'stop' CHECK (type IN ('start','stop','end')),
  sort_order INT DEFAULT 0,
  lat        NUMERIC(10,7),
  lng        NUMERIC(10,7),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ride_participants (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id   UUID REFERENCES rides(id) ON DELETE CASCADE,
  user_id   UUID REFERENCES users(id) ON DELETE CASCADE,
  role      VARCHAR(30) DEFAULT 'member' CHECK (role IN ('host','lead','marshal','sweep','member')),
  status    VARCHAR(30) DEFAULT 'joined' CHECK (status IN ('joined','pending','invited','declined')),
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(ride_id, user_id)
);

CREATE TABLE IF NOT EXISTS ride_weather (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ride_id    UUID REFERENCES rides(id) ON DELETE CASCADE,
  point      VARCHAR(10) CHECK (point IN ('start','end')),
  temp       INT,
  condition  VARCHAR(80),
  wind       VARCHAR(40),
  fetched_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS groups (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        VARCHAR(150) NOT NULL,
  description TEXT,
  location    VARCHAR(150),
  is_public   BOOLEAN DEFAULT TRUE,
  avatar_url  TEXT,
  total_rides INT DEFAULT 0,
  total_km    VARCHAR(20) DEFAULT '0',
  created_by  UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS group_members (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id  UUID REFERENCES groups(id) ON DELETE CASCADE,
  user_id   UUID REFERENCES users(id) ON DELETE CASCADE,
  role      VARCHAR(20) DEFAULT 'member' CHECK (role IN ('admin','member')),
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(group_id, user_id)
);

CREATE TABLE IF NOT EXISTS group_rules (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    UUID REFERENCES groups(id) ON DELETE CASCADE,
  emoji       VARCHAR(10),
  title       VARCHAR(200) NOT NULL,
  description TEXT,
  is_default  BOOLEAN DEFAULT FALSE,
  sort_order  INT DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS group_messages (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id  UUID REFERENCES groups(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES users(id) ON DELETE SET NULL,
  message   TEXT NOT NULL,
  type      VARCHAR(20) DEFAULT 'text' CHECK (type IN ('text','system','pinned','image')),
  sent_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS expenses (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID REFERENCES users(id) ON DELETE CASCADE,
  vehicle_id     UUID REFERENCES vehicles(id) ON DELETE SET NULL,
  ride_id        UUID REFERENCES rides(id) ON DELETE SET NULL,
  category       VARCHAR(30) NOT NULL CHECK (category IN ('Fuel','Food','Maintenance','Toll','Parking','Other')),
  amount         NUMERIC(10,2) NOT NULL,
  date           DATE NOT NULL,
  description    VARCHAR(300),
  notes          TEXT,
  type           VARCHAR(20) DEFAULT 'personal' CHECK (type IN ('personal','ride')),
  payment_method VARCHAR(20) DEFAULT 'cash' CHECK (payment_method IN ('cash','upi','card','wallet')),
  location       VARCHAR(150),
  receipt_count  INT DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS accessories (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES users(id) ON DELETE CASCADE,
  vehicle_id    UUID REFERENCES vehicles(id) ON DELETE SET NULL,
  name          VARCHAR(200) NOT NULL,
  brand         VARCHAR(100),
  type          VARCHAR(50) NOT NULL,
  price         NUMERIC(10,2) DEFAULT 0,
  purchase_date DATE,
  size          VARCHAR(20),
  color         VARCHAR(60),
  store         VARCHAR(200),
  emoji         VARCHAR(10) DEFAULT '🔧',
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS marketplace_listings (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id    UUID REFERENCES users(id) ON DELETE CASCADE,
  title        VARCHAR(250) NOT NULL,
  description  TEXT,
  price        NUMERIC(12,2) NOT NULL,
  condition    VARCHAR(30) DEFAULT 'Good',
  category     VARCHAR(50) NOT NULL,
  location     VARCHAR(150),
  images       TEXT[] DEFAULT '{}',
  contact_pref VARCHAR(30) DEFAULT 'Chat Only',
  is_active    BOOLEAN DEFAULT TRUE,
  views        INT DEFAULT 0,
  bike_brand   VARCHAR(100), bike_model VARCHAR(100), bike_year INT,
  bike_km      INT,          fuel_type  VARCHAR(30),  transmission VARCHAR(30),
  num_owners   VARCHAR(10),
  gear_type    VARCHAR(50),  gear_size  VARCHAR(20),  gear_gender VARCHAR(20),
  certification VARCHAR(30),
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sos_alerts (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES users(id) ON DELETE CASCADE,
  ride_id    UUID REFERENCES rides(id) ON DELETE SET NULL,
  lat        NUMERIC(10,7),
  lng        NUMERIC(10,7),
  message    TEXT,
  status     VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active','resolved')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── INDEXES ───────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_rides_host       ON rides(host_id);
CREATE INDEX IF NOT EXISTS idx_rides_status     ON rides(status);
CREATE INDEX IF NOT EXISTS idx_rides_start_date ON rides(start_date);
CREATE INDEX IF NOT EXISTS idx_rpart_ride       ON ride_participants(ride_id);
CREATE INDEX IF NOT EXISTS idx_rpart_user       ON ride_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_expenses_user    ON expenses(user_id);
CREATE INDEX IF NOT EXISTS idx_expenses_ride    ON expenses(ride_id);
CREATE INDEX IF NOT EXISTS idx_grp_members_grp  ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_grp_members_user ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_market_seller    ON marketplace_listings(seller_id);
CREATE INDEX IF NOT EXISTS idx_market_category  ON marketplace_listings(category);
CREATE INDEX IF NOT EXISTS idx_accessories_user ON accessories(user_id);

-- ── SEED DATA ─────────────────────────────────────────────────────────────────
-- Password for all users = "password123"
-- Hash: $2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi

INSERT INTO users (id, name, email, password_hash, phone, city, bio, total_rides, total_km) VALUES
  ('a0000001-0000-0000-0000-000000000001','Rahul Kumar',  'rahul@example.com',   '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','9876543210','Mumbai',    'Passionate biker. Ride or die.', 45,12500),
  ('a0000001-0000-0000-0000-000000000002','John Smith',   'john@example.com',    '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','9876543211','Delhi',     'Long-distance touring enthusiast.',30,9800),
  ('a0000001-0000-0000-0000-000000000003','Priya Sharma', 'priya@example.com',   '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','9876543212','Pune',      'Adventure & mountain rides.',28,7200),
  ('a0000001-0000-0000-0000-000000000004','Amit Singh',   'amit@example.com',    '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','9876543213','Bangalore', 'City rides and weekend trips.',15,4100),
  ('a0000001-0000-0000-0000-000000000005','Sanjay Kumar', 'sanjay@example.com',  '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','9876543214','Mumbai',    'Royal Enfield fan.',32,8900),
  ('a0000001-0000-0000-0000-000000000006','Priya Nair',   'priya.n@example.com', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','9876543215','Hyderabad', 'KTM rider and trail explorer.',20,5600),
  ('a0000001-0000-0000-0000-000000000007','Rajesh Kumar', 'rajesh@example.com',  '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','9876543216','Mumbai',    'Group ride organiser.',50,18000),
  ('a0000001-0000-0000-0000-000000000008','Arjun Mehta',  'arjun@example.com',   '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi','9876543217','Delhi',     'Dominar tourer.',8,2100)
ON CONFLICT (email) DO NOTHING;

INSERT INTO vehicles (id, user_id, name, nickname, brand, model, year, engine_cc, fuel_type, color) VALUES
  ('b0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000001','Royal Enfield Classic 350','Beast',     'Royal Enfield','Classic 350',2022,350,'Petrol','Stealth Black'),
  ('b0000001-0000-0000-0000-000000000002','a0000001-0000-0000-0000-000000000001','Bajaj Dominar 400',        'Dominator', 'Bajaj',        'Dominar 400',2023,400,'Petrol','Aurora Green'),
  ('b0000001-0000-0000-0000-000000000003','a0000001-0000-0000-0000-000000000001','Royal Enfield Himalayan',  'Mountain',  'Royal Enfield','Himalayan',  2021,411,'Petrol','Gravel Grey'),
  ('b0000001-0000-0000-0000-000000000004','a0000001-0000-0000-0000-000000000002','Yamaha R1',                'R1',        'Yamaha',       'YZF-R1',     2023,998,'Petrol','Midnight Black'),
  ('b0000001-0000-0000-0000-000000000005','a0000001-0000-0000-0000-000000000003','KTM Duke 390',             'Duke',      'KTM',          'Duke 390',   2024,390,'Petrol','White'),
  ('b0000001-0000-0000-0000-000000000006','a0000001-0000-0000-0000-000000000004','BMW S1000RR',              'Beemer',    'BMW',          'S1000RR',    2023,999,'Petrol','Racing Red')
ON CONFLICT (id) DO NOTHING;

INSERT INTO rides (id, name, description, source, destination, start_date, start_time, end_date, end_time,
                   total_km, duration, is_public, is_paid, entry_fee, max_participants, cloned_count,
                   status, tags, host_id, lead_rider_id, marshal_id, sweep_id) VALUES
  ('c0000001-0000-0000-0000-000000000001',
   'Lonavala Weekend Ride','A thrilling weekend escape from Mumbai to the scenic ghats of Lonavala.',
   'Mumbai','Lonavala','2026-02-15','06:00:00','2026-02-15','14:00:00',
   245,'8 hrs',true,false,0,20,12,'upcoming',ARRAY['Public','Upcoming'],
   'a0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000001',
   'a0000001-0000-0000-0000-000000000002','a0000001-0000-0000-0000-000000000003'),

  ('c0000001-0000-0000-0000-000000000002',
   'Coastal Highway Run','Breathtaking coastal drive from Bandra to Alibaug along the scenic Konkan coastline.',
   'Bandra','Alibaug','2026-02-18','05:30:00','2026-02-18','17:30:00',
   580,'12 hrs',true,true,200,15,8,'upcoming',ARRAY['Public','Paid','Upcoming'],
   'a0000001-0000-0000-0000-000000000002','a0000001-0000-0000-0000-000000000002',
   'a0000001-0000-0000-0000-000000000004','a0000001-0000-0000-0000-000000000003'),

  ('c0000001-0000-0000-0000-000000000003',
   'Pune Express','Quick morning dash from Mumbai to Pune on the expressway.',
   'Mumbai','Pune','2026-02-22','05:00:00','2026-02-22','08:00:00',
   150,'3 hrs',true,false,0,25,5,'upcoming',ARRAY['Public','Upcoming'],
   'a0000001-0000-0000-0000-000000000003','a0000001-0000-0000-0000-000000000003',
   NULL,NULL),

  ('c0000001-0000-0000-0000-000000000004',
   'Himalayan Adventure','Epic 90-hour journey from Delhi to Leh through the mighty Himalayas.',
   'Delhi','Leh','2026-01-05','15:00:00','2026-01-09','09:00:00',
   9999,'90 hrs',true,true,1500,15,100,'upcoming',ARRAY['Public','Paid','Scenic','Adventure'],
   'a0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000001',
   'a0000001-0000-0000-0000-000000000004','a0000001-0000-0000-0000-000000000002'),

  ('c0000001-0000-0000-0000-000000000005',
   'Goa Beach Cruise','Three-day coastal ride culminating in the beaches of Goa.',
   'Pune','Goa','2025-12-20','06:00:00','2025-12-22','18:00:00',
   595,'36 hrs',true,true,500,20,22,'completed',ARRAY['Public','Paid'],
   'a0000001-0000-0000-0000-000000000002','a0000001-0000-0000-0000-000000000002',
   'a0000001-0000-0000-0000-000000000003','a0000001-0000-0000-0000-000000000004'),

  ('c0000001-0000-0000-0000-000000000006',
   'Sunrise Sinhagad Climb','Pre-dawn ride to the historic Sinhagad fort to catch the sunrise.',
   'Pune','Sinhagad Fort','2025-11-10','04:00:00','2025-11-10','10:00:00',
   50,'6 hrs',true,false,0,30,7,'completed',ARRAY['Public','Scenic'],
   'a0000001-0000-0000-0000-000000000003','a0000001-0000-0000-0000-000000000003',
   NULL,NULL),

  ('c0000001-0000-0000-0000-000000000007',
   'Manali Winter Ride','Experience the snowclad Manali roads before the passes close for winter.',
   'Delhi','Manali','2026-03-25','07:00:00','2026-03-27','15:00:00',
   1050,'50 hrs',false,true,800,10,3,'upcoming',ARRAY['Highway','Adventure'],
   'a0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000001',
   'a0000001-0000-0000-0000-000000000002',NULL),

  ('c0000001-0000-0000-0000-000000000008',
   'Bangalore Night Blaze','City loop night ride exploring Bangalore landmarks.',
   'Bangalore','Bangalore City Loop','2026-02-28','22:00:00','2026-03-01','06:00:00',
   120,'8 hrs',true,false,0,40,15,'upcoming',ARRAY['Public','Highway'],
   'a0000001-0000-0000-0000-000000000004','a0000001-0000-0000-0000-000000000004',
   NULL,NULL)
ON CONFLICT (id) DO NOTHING;

INSERT INTO ride_waypoints (ride_id, name, time, type, sort_order) VALUES
  ('c0000001-0000-0000-0000-000000000001','Mumbai',                   '6:00 AM', 'start',0),
  ('c0000001-0000-0000-0000-000000000001','Breakfast Stop: Lonavala', '8:30 AM', 'stop', 1),
  ('c0000001-0000-0000-0000-000000000001','Photo Stop: Khandala Ghats','10:00 AM','stop', 2),
  ('c0000001-0000-0000-0000-000000000001','Lonavala',                 '12:00 PM','end',  3),
  ('c0000001-0000-0000-0000-000000000002','Bandra',                   '5:30 AM', 'start',0),
  ('c0000001-0000-0000-0000-000000000002','Alibaug Ferry',            '9:00 AM', 'stop', 1),
  ('c0000001-0000-0000-0000-000000000002','Alibaug',                  '5:30 PM', 'end',  2),
  ('c0000001-0000-0000-0000-000000000003','Mumbai',                   '5:00 AM', 'start',0),
  ('c0000001-0000-0000-0000-000000000003','Pune',                     '8:00 AM', 'end',  1),
  ('c0000001-0000-0000-0000-000000000004','Delhi',                    '3:00 PM', 'start',0),
  ('c0000001-0000-0000-0000-000000000004','Chandigarh Fuel Stop',     '7:00 PM', 'stop', 1),
  ('c0000001-0000-0000-0000-000000000004','Manali Rest',              '6:00 AM', 'stop', 2),
  ('c0000001-0000-0000-0000-000000000004','Rohtang Pass',             '11:00 AM','stop', 3),
  ('c0000001-0000-0000-0000-000000000004','Leh',                      '9:00 AM', 'end',  4);

INSERT INTO ride_participants (ride_id, user_id, role, status) VALUES
  ('c0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000001','host',   'joined'),
  ('c0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000002','marshal','joined'),
  ('c0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000003','member', 'joined'),
  ('c0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000004','member', 'joined'),
  ('c0000001-0000-0000-0000-000000000002','a0000001-0000-0000-0000-000000000002','host',   'joined'),
  ('c0000001-0000-0000-0000-000000000002','a0000001-0000-0000-0000-000000000001','member', 'joined'),
  ('c0000001-0000-0000-0000-000000000002','a0000001-0000-0000-0000-000000000003','member', 'joined'),
  ('c0000001-0000-0000-0000-000000000003','a0000001-0000-0000-0000-000000000003','host',   'joined'),
  ('c0000001-0000-0000-0000-000000000003','a0000001-0000-0000-0000-000000000004','member', 'joined'),
  ('c0000001-0000-0000-0000-000000000004','a0000001-0000-0000-0000-000000000001','host',   'joined'),
  ('c0000001-0000-0000-0000-000000000004','a0000001-0000-0000-0000-000000000004','marshal','joined'),
  ('c0000001-0000-0000-0000-000000000004','a0000001-0000-0000-0000-000000000006','member', 'joined')
ON CONFLICT (ride_id, user_id) DO NOTHING;

INSERT INTO ride_weather (ride_id, point, temp, condition, wind) VALUES
  ('c0000001-0000-0000-0000-000000000001','start',28,'Sunny',        '12 km/h'),
  ('c0000001-0000-0000-0000-000000000001','end',  25,'Partly Cloudy','8 km/h'),
  ('c0000001-0000-0000-0000-000000000002','start',30,'Sunny',        '15 km/h'),
  ('c0000001-0000-0000-0000-000000000002','end',  27,'Clear',        '10 km/h'),
  ('c0000001-0000-0000-0000-000000000003','start',26,'Clear',        '10 km/h'),
  ('c0000001-0000-0000-0000-000000000003','end',  24,'Sunny',        '6 km/h');

INSERT INTO groups (id, name, description, location, is_public, total_rides, total_km, created_by) VALUES
  ('d0000001-0000-0000-0000-000000000001','Mumbai Riders',         'City rides and weekend adventures',          'Mumbai',          true, 9, '78k', 'a0000001-0000-0000-0000-000000000001'),
  ('d0000001-0000-0000-0000-000000000002','Weekend Warriors',      'Weekend sunrise & night rides',              'Pune',            true, 7, '45k', 'a0000001-0000-0000-0000-000000000002'),
  ('d0000001-0000-0000-0000-000000000003','Goa Beach Riders',      'Coastal rides and beach adventures',         'Goa',             true,17,'120k', 'a0000001-0000-0000-0000-000000000003'),
  ('d0000001-0000-0000-0000-000000000004','Himalayan Explorers',   'Mountain treks and high altitude adventures','Himachal Pradesh',true,31,'250k', 'a0000001-0000-0000-0000-000000000001'),
  ('d0000001-0000-0000-0000-000000000005','Bangalore Night Riders','Night rides and city exploration',           'Bangalore',      false,14,'65k',  'a0000001-0000-0000-0000-000000000004'),
  ('d0000001-0000-0000-0000-000000000006','Pune Speed Demons',     'Track days and speed enthusiasts',           'Pune',            true, 8, '40k', 'a0000001-0000-0000-0000-000000000002'),
  ('d0000001-0000-0000-0000-000000000007','Delhi NCR Cruisers',    'Highway cruising and long-distance riders',  'Delhi NCR',       true,45,'380k', 'a0000001-0000-0000-0000-000000000003'),
  ('d0000001-0000-0000-0000-000000000008','Royal Enfield Owners',  'For Royal Enfield enthusiasts',              'Multiple',        true,22,'190k', 'a0000001-0000-0000-0000-000000000004')
ON CONFLICT (id) DO NOTHING;

INSERT INTO group_members (group_id, user_id, role) VALUES
  ('d0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000001','admin'),
  ('d0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000002','admin'),
  ('d0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000003','member'),
  ('d0000001-0000-0000-0000-000000000001','a0000001-0000-0000-0000-000000000004','member'),
  ('d0000001-0000-0000-0000-000000000002','a0000001-0000-0000-0000-000000000002','admin'),
  ('d0000001-0000-0000-0000-000000000002','a0000001-0000-0000-0000-000000000003','member'),
  ('d0000001-0000-0000-0000-000000000003','a0000001-0000-0000-0000-000000000003','admin'),
  ('d0000001-0000-0000-0000-000000000004','a0000001-0000-0000-0000-000000000001','admin'),
  ('d0000001-0000-0000-0000-000000000004','a0000001-0000-0000-0000-000000000002','member'),
  ('d0000001-0000-0000-0000-000000000005','a0000001-0000-0000-0000-000000000004','admin'),
  ('d0000001-0000-0000-0000-000000000006','a0000001-0000-0000-0000-000000000002','admin'),
  ('d0000001-0000-0000-0000-000000000007','a0000001-0000-0000-0000-000000000003','admin'),
  ('d0000001-0000-0000-0000-000000000008','a0000001-0000-0000-0000-000000000004','admin')
ON CONFLICT (group_id, user_id) DO NOTHING;

INSERT INTO expenses (user_id, vehicle_id, ride_id, category, amount, date, description, type, payment_method, location) VALUES
  ('a0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000001','c0000001-0000-0000-0000-000000000001','Fuel',        1200,'2024-11-20','Gas station stop at Mumbai highway','ride',    'upi', 'Mumbai'),
  ('a0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000001','c0000001-0000-0000-0000-000000000001','Food',         450,'2024-11-20','Lunch break at coastal restaurant', 'ride',    'cash','Mumbai'),
  ('a0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000001','c0000001-0000-0000-0000-000000000003','Toll',         120,'2026-02-26','Mumbai-Pune Express toll',          'ride',    'cash',NULL),
  ('a0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000001','c0000001-0000-0000-0000-000000000003','Fuel',        1200,'2026-02-24','Group ride fuel',                   'ride',    'upi', NULL),
  ('a0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000001','c0000001-0000-0000-0000-000000000003','Food',         850,'2026-02-24','Dhaba meal',                        'ride',    'cash',NULL),
  ('a0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000001',NULL,                                 'Maintenance', 3500,'2024-11-18','Chain adjustment and oil change',   'personal','upi', NULL),
  ('a0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000001',NULL,                                 'Fuel',         850,'2026-02-26','Shell Petrol Pump',                 'personal','upi', NULL),
  ('a0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000001',NULL,                                 'Maintenance', 2500,'2026-02-23','Oil change',                        'personal','card',NULL),
  ('a0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000001',NULL,                                 'Fuel',         900,'2026-02-22','HP Petrol',                         'personal','upi', NULL),
  ('a0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000001',NULL,                                 'Maintenance', 1800,'2026-02-11','Brake pad replacement',             'personal','card',NULL),
  ('a0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000001',NULL,                                 'Toll',         180,'2026-02-06','Highway toll',                      'personal','cash',NULL),
  ('a0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000001',NULL,                                 'Other',        500,'2026-02-01','Bike wash',                         'personal','cash',NULL);

INSERT INTO accessories (user_id, vehicle_id, name, brand, type, price, purchase_date, size, color, store, emoji) VALUES
  ('a0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000003','K6 S Helmet',              'AGV',           'Helmet', 35000,'2024-01-15','L', 'Matte Black','BikeRyders Store, Mumbai','🪖'),
  ('a0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000003','T-GP Plus R v3 Air Jacket','Alpinestars',   'Jacket', 28000,'2024-02-10','XL','Black/White', 'Amazon India',            '🧥'),
  ('a0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000003','Summer Gloves',            'Royal Enfield', 'Gloves',  2500,'2024-03-05','M', 'Brown',       'Royal Enfield Store',     '🧤'),
  ('a0000001-0000-0000-0000-000000000001','b0000001-0000-0000-0000-000000000003','Touring Boots',            'Alpinestars',   'Boots',  15000,'2024-04-12','42','Black',        'BikeRyders Store',        '🥾');

INSERT INTO marketplace_listings (seller_id, title, description, price, condition, category, location, contact_pref, bike_brand, bike_model, bike_year, bike_km, fuel_type, transmission, num_owners) VALUES
  ('a0000001-0000-0000-0000-000000000001','Royal Enfield Classic 350','Well maintained Classic 350 in Stealth Black. Single owner.',125000,'Like New','Bikes','Mumbai','Call Allowed','Royal Enfield','Classic 350',2022,12000,'Petrol','Manual','1st'),
  ('a0000001-0000-0000-0000-000000000002','Bajaj Pulsar NS200','Sporty NS200 with recent service. Minor scratch on left fairing.',85000,'Good','Bikes','Pune','Chat Only','Bajaj','Pulsar NS200',2021,22000,'Petrol','Manual','2nd');

INSERT INTO marketplace_listings (seller_id, title, description, price, condition, category, location, contact_pref, gear_type, gear_size, gear_gender, certification) VALUES
  ('a0000001-0000-0000-0000-000000000003','SMK Stellar Helmet',   'Barely used. Full-face with visor.',           4500,'New', 'Gear','Pune',     'Chat Only',   'Helmet','L', 'Men','ECE'),
  ('a0000001-0000-0000-0000-000000000004','Leather Riding Jacket','CE level 2 armour. Size XL.',                  8500,'Good','Gear','Mumbai',   'Chat Only',   'Jacket','XL','Men', NULL),
  ('a0000001-0000-0000-0000-000000000003','Rynox Air GT Gloves',  'Mesh summer gloves. Used only 3 times.',       1800,'New', 'Gear','Bangalore','Call Allowed', 'Gloves','M', 'Men', NULL);

INSERT INTO marketplace_listings (seller_id, title, description, price, condition, category, location, contact_pref) VALUES
  ('a0000001-0000-0000-0000-000000000005','Saddle Bags Set',      'Weatherproof saddle bags, fits most bikes.',  3200,'New', 'Accessories','Delhi',    'Chat Only'),
  ('a0000001-0000-0000-0000-000000000006','LED Fog Lights (Pair)','Universal fit LED fog lights with harness.',  2400,'New', 'Parts',      'Hyderabad','Chat Only'),
  ('a0000001-0000-0000-0000-000000000006','Chain Tensioner Kit',  'Heavy duty chain kit. Fits RE, Dominar.',    1200,'Good','Parts',      'Chennai',  'Call Allowed');
