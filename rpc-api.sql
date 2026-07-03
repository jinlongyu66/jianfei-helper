-- ============================================================
-- 减脂助手 — RPC 函数（SECURITY DEFINER 模式）
-- 在 schema.sql 执行后再执行此文件
-- ============================================================

-- ============================================================
-- 内部函数：校验 token
-- ============================================================
CREATE OR REPLACE FUNCTION fit_check_token(tok UUID)
RETURNS INTEGER AS $$
DECLARE
    uid INTEGER;
BEGIN
    SELECT user_id INTO uid FROM fit_sessions
    WHERE token = tok AND expires_at > NOW();
    IF uid IS NULL THEN
        RAISE EXCEPTION 'invalid token';
    END IF;
    RETURN uid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 注册
-- ============================================================
CREATE OR REPLACE FUNCTION fit_register(uname TEXT, pwd TEXT)
RETURNS JSON AS $$
DECLARE
    new_id INTEGER;
    new_token UUID;
BEGIN
    -- 检查用户名是否已存在
    IF EXISTS (SELECT 1 FROM fit_users WHERE username = uname) THEN
        RETURN json_build_object('ok', false, 'error', '用户名已被注册');
    END IF;

    -- 创建用户
    INSERT INTO fit_users (username, password_hash)
    VALUES (uname, crypt(pwd, gen_salt('bf')))
    RETURNING id INTO new_id;

    -- 创建空白身体数据
    INSERT INTO fit_profile (user_id) VALUES (new_id);

    -- 创建会话
    INSERT INTO fit_sessions (user_id)
    VALUES (new_id)
    RETURNING token INTO new_token;

    RETURN json_build_object('ok', true, 'token', new_token, 'user_id', new_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 登录
-- ============================================================
CREATE OR REPLACE FUNCTION fit_login(uname TEXT, pwd TEXT)
RETURNS JSON AS $$
DECLARE
    uid INTEGER;
    new_token UUID;
BEGIN
    SELECT id INTO uid FROM fit_users
    WHERE username = uname AND password_hash = crypt(pwd, password_hash);

    IF uid IS NULL THEN
        RETURN json_build_object('ok', false, 'error', '用户名或密码错误');
    END IF;

    -- 创建新会话
    INSERT INTO fit_sessions (user_id) VALUES (uid)
    RETURNING token INTO new_token;

    RETURN json_build_object('ok', true, 'token', new_token, 'user_id', uid);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 退出登录
-- ============================================================
CREATE OR REPLACE FUNCTION fit_logout(tok UUID)
RETURNS JSON AS $$
BEGIN
    DELETE FROM fit_sessions WHERE token = tok;
    RETURN json_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 修改密码
-- ============================================================
CREATE OR REPLACE FUNCTION fit_change_pw(tok UUID, old_pwd TEXT, new_pwd TEXT)
RETURNS JSON AS $$
DECLARE
    uid INTEGER;
BEGIN
    SELECT user_id INTO uid FROM fit_sessions
    WHERE token = tok AND expires_at > NOW();
    IF uid IS NULL THEN
        RETURN json_build_object('ok', false, 'error', '登录已过期');
    END IF;

    -- 验证旧密码
    IF NOT EXISTS (
        SELECT 1 FROM fit_users
        WHERE id = uid AND password_hash = crypt(old_pwd, password_hash)
    ) THEN
        RETURN json_build_object('ok', false, 'error', '旧密码错误');
    END IF;

    UPDATE fit_users SET password_hash = crypt(new_pwd, gen_salt('bf'))
    WHERE id = uid;

    RETURN json_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 获取我的身体数据
-- ============================================================
CREATE OR REPLACE FUNCTION fit_get_profile(tok UUID)
RETURNS JSON AS $$
DECLARE
    uid INTEGER;
    result JSON;
BEGIN
    uid := fit_check_token(tok);

    SELECT row_to_json(p) INTO result
    FROM (
        SELECT height, weight, target_weight, age, gender,
               activity_level, deficit, time_available, equipment,
               has_kitchen, updated_at
        FROM fit_profile WHERE user_id = uid
    ) p;

    RETURN COALESCE(result, '{}'::JSON);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 保存身体数据
-- ============================================================
CREATE OR REPLACE FUNCTION fit_save_profile(
    tok UUID,
    p_height NUMERIC,
    p_weight NUMERIC,
    p_target_weight NUMERIC,
    p_age INTEGER,
    p_gender TEXT,
    p_activity_level TEXT,
    p_deficit INTEGER,
    p_time_available INTEGER,
    p_equipment TEXT,
    p_has_kitchen BOOLEAN
)
RETURNS JSON AS $$
DECLARE
    uid INTEGER;
BEGIN
    uid := fit_check_token(tok);

    INSERT INTO fit_profile (user_id, height, weight, target_weight, age, gender,
        activity_level, deficit, time_available, equipment, has_kitchen, updated_at)
    VALUES (uid, p_height, p_weight, p_target_weight, p_age, p_gender,
        p_activity_level, p_deficit, p_time_available, p_equipment, p_has_kitchen, NOW())
    ON CONFLICT (user_id) DO UPDATE SET
        height = EXCLUDED.height,
        weight = EXCLUDED.weight,
        target_weight = EXCLUDED.target_weight,
        age = EXCLUDED.age,
        gender = EXCLUDED.gender,
        activity_level = EXCLUDED.activity_level,
        deficit = EXCLUDED.deficit,
        time_available = EXCLUDED.time_available,
        equipment = EXCLUDED.equipment,
        has_kitchen = EXCLUDED.has_kitchen,
        updated_at = NOW();

    RETURN json_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 获取体重记录
-- ============================================================
CREATE OR REPLACE FUNCTION fit_get_weight_logs(tok UUID)
RETURNS JSON AS $$
DECLARE
    uid INTEGER;
    result JSON;
BEGIN
    uid := fit_check_token(tok);

    SELECT json_agg(row_to_json(t)) INTO result
    FROM (
        SELECT id, log_date, weight, note, created_at
        FROM fit_weight_logs
        WHERE user_id = uid
        ORDER BY log_date DESC
        LIMIT 365
    ) t;

    RETURN COALESCE(result, '[]'::JSON);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 添加体重记录
-- ============================================================
CREATE OR REPLACE FUNCTION fit_add_weight_log(tok UUID, p_date DATE, p_weight NUMERIC, p_note TEXT DEFAULT NULL)
RETURNS JSON AS $$
DECLARE
    uid INTEGER;
    new_id INTEGER;
BEGIN
    uid := fit_check_token(tok);

    INSERT INTO fit_weight_logs (user_id, log_date, weight, note)
    VALUES (uid, p_date, p_weight, p_note)
    RETURNING id INTO new_id;

    -- 自动更新 profile 里的当前体重
    UPDATE fit_profile SET weight = p_weight, updated_at = NOW()
    WHERE user_id = uid;

    RETURN json_build_object('ok', true, 'id', new_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 删除体重记录
-- ============================================================
CREATE OR REPLACE FUNCTION fit_del_weight_log(tok UUID, p_id INTEGER)
RETURNS JSON AS $$
DECLARE
    uid INTEGER;
BEGIN
    uid := fit_check_token(tok);
    DELETE FROM fit_weight_logs WHERE id = p_id AND user_id = uid;
    RETURN json_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 获取今日饮食记录
-- ============================================================
CREATE OR REPLACE FUNCTION fit_get_food_logs(tok UUID, p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSON AS $$
DECLARE
    uid INTEGER;
    result JSON;
BEGIN
    uid := fit_check_token(tok);

    SELECT json_agg(row_to_json(t)) INTO result
    FROM (
        SELECT id, meal_type, description, calories, protein, carbs, fat, created_at
        FROM fit_food_logs
        WHERE user_id = uid AND log_date = p_date
        ORDER BY created_at ASC
    ) t;

    RETURN COALESCE(result, '[]'::JSON);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 添加饮食记录
-- ============================================================
CREATE OR REPLACE FUNCTION fit_add_food_log(
    tok UUID, p_date DATE, p_meal_type TEXT, p_description TEXT,
    p_calories NUMERIC, p_protein NUMERIC, p_carbs NUMERIC, p_fat NUMERIC
)
RETURNS JSON AS $$
DECLARE
    uid INTEGER;
    new_id INTEGER;
BEGIN
    uid := fit_check_token(tok);

    INSERT INTO fit_food_logs (user_id, log_date, meal_type, description, calories, protein, carbs, fat)
    VALUES (uid, p_date, p_meal_type, p_description, p_calories, p_protein, p_carbs, p_fat)
    RETURNING id INTO new_id;

    RETURN json_build_object('ok', true, 'id', new_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 删除饮食记录
-- ============================================================
CREATE OR REPLACE FUNCTION fit_del_food_log(tok UUID, p_id INTEGER)
RETURNS JSON AS $$
DECLARE
    uid INTEGER;
BEGIN
    uid := fit_check_token(tok);
    DELETE FROM fit_food_logs WHERE id = p_id AND user_id = uid;
    RETURN json_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 每日打卡
-- ============================================================
CREATE OR REPLACE FUNCTION fit_checkin(tok UUID, p_date DATE, p_diet BOOLEAN, p_exercise BOOLEAN, p_note TEXT DEFAULT NULL)
RETURNS JSON AS $$
DECLARE
    uid INTEGER;
BEGIN
    uid := fit_check_token(tok);

    INSERT INTO fit_checkins (user_id, check_date, diet_ok, exercise_ok, note)
    VALUES (uid, p_date, p_diet, p_exercise, p_note)
    ON CONFLICT (user_id, check_date) DO UPDATE SET
        diet_ok = EXCLUDED.diet_ok,
        exercise_ok = EXCLUDED.exercise_ok,
        note = EXCLUDED.note;

    RETURN json_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 获取打卡状态
-- ============================================================
CREATE OR REPLACE FUNCTION fit_get_checkin(tok UUID, p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSON AS $$
DECLARE
    uid INTEGER;
    result JSON;
BEGIN
    uid := fit_check_token(tok);

    SELECT row_to_json(t) INTO result
    FROM (
        SELECT diet_ok, exercise_ok, note
        FROM fit_checkins
        WHERE user_id = uid AND check_date = p_date
    ) t;

    RETURN COALESCE(result, json_build_object('diet_ok', false, 'exercise_ok', false, 'note', ''));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
