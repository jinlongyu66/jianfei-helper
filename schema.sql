-- ============================================================
-- 减脂助手 — Supabase 数据库初始化
-- 在 Supabase SQL Editor 中执行此文件
-- ============================================================

-- 启用 pgcrypto（密码哈希）
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 用户表
-- ============================================================
CREATE TABLE IF NOT EXISTS fit_users (
    id SERIAL PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 会话表
-- ============================================================
CREATE TABLE IF NOT EXISTS fit_sessions (
    id SERIAL PRIMARY KEY,
    token UUID DEFAULT gen_random_uuid(),
    user_id INTEGER REFERENCES fit_users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '30 days')
);

-- ============================================================
-- 身体数据（每个用户一行）
-- ============================================================
CREATE TABLE IF NOT EXISTS fit_profile (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES fit_users(id) ON DELETE CASCADE UNIQUE,
    height NUMERIC,            -- 身高 cm
    weight NUMERIC,            -- 当前体重 kg
    target_weight NUMERIC,     -- 目标体重 kg
    age INTEGER,               -- 年龄
    gender TEXT,               -- 'male' | 'female'
    activity_level TEXT,       -- 'sedentary' | 'light' | 'moderate' | 'active'
    deficit INTEGER DEFAULT 300,       -- 热量缺口 kcal
    time_available INTEGER DEFAULT 30, -- 可用运动时间（分钟）
    equipment TEXT DEFAULT 'none',     -- 'none'|'bands'|'dumbbell'|'gym'
    has_kitchen BOOLEAN DEFAULT false,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 体重记录
-- ============================================================
CREATE TABLE IF NOT EXISTS fit_weight_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES fit_users(id) ON DELETE CASCADE,
    log_date DATE NOT NULL DEFAULT CURRENT_DATE,
    weight NUMERIC NOT NULL,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_weight_user_date ON fit_weight_logs(user_id, log_date DESC);

-- ============================================================
-- 饮食记录（AI 估热）
-- ============================================================
CREATE TABLE IF NOT EXISTS fit_food_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES fit_users(id) ON DELETE CASCADE,
    log_date DATE NOT NULL DEFAULT CURRENT_DATE,
    meal_type TEXT NOT NULL DEFAULT 'lunch',  -- 'breakfast'|'lunch'|'dinner'|'snack'
    description TEXT,           -- 用户原始输入
    calories NUMERIC,           -- AI 估算热量
    protein NUMERIC,            -- 蛋白质 g
    carbs NUMERIC,              -- 碳水 g
    fat NUMERIC,                -- 脂肪 g
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_food_user_date ON fit_food_logs(user_id, log_date DESC);

-- ============================================================
-- 每日打卡
-- ============================================================
CREATE TABLE IF NOT EXISTS fit_checkins (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES fit_users(id) ON DELETE CASCADE,
    check_date DATE NOT NULL DEFAULT CURRENT_DATE,
    diet_ok BOOLEAN DEFAULT false,
    exercise_ok BOOLEAN DEFAULT false,
    note TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, check_date)
);
