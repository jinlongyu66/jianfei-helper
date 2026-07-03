-- ============================================================
-- 减脂助手 v2 — 追加表 + 列
-- ============================================================

-- 1. 作息时间
ALTER TABLE fit_profile ADD COLUMN IF NOT EXISTS wake_time TEXT DEFAULT '08:00';
ALTER TABLE fit_profile ADD COLUMN IF NOT EXISTS sleep_time TEXT DEFAULT '23:00';
ALTER TABLE fit_profile ADD COLUMN IF NOT EXISTS sleep_hours NUMERIC;

-- 2. 快捷食谱
CREATE TABLE IF NOT EXISTS fit_saved_meals (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES fit_users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    calories NUMERIC DEFAULT 0,
    protein NUMERIC DEFAULT 0,
    carbs NUMERIC DEFAULT 0,
    fat NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. 喝水记录
CREATE TABLE IF NOT EXISTS fit_water_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES fit_users(id) ON DELETE CASCADE,
    log_date DATE DEFAULT CURRENT_DATE,
    cups INTEGER DEFAULT 1
);

-- 4. 每日状态（精力+心情）
CREATE TABLE IF NOT EXISTS fit_daily_state (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES fit_users(id) ON DELETE CASCADE,
    state_date DATE DEFAULT CURRENT_DATE,
    energy INTEGER CHECK (energy BETWEEN 1 AND 5),   -- 1=很累 5=精力充沛
    mood INTEGER CHECK (mood BETWEEN 1 AND 5),        -- 1=很差 5=很好
    note TEXT,
    UNIQUE(user_id, state_date)
);

-- 5. 体重记录加索引
CREATE INDEX IF NOT EXISTS idx_weight_user_date2 ON fit_weight_logs(user_id, log_date);
