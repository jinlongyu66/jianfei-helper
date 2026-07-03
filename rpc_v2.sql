-- ============================================================
-- 减脂助手 v2 — 新增 RPC 函数
-- ============================================================

-- ============================================================
-- 更新 save_profile 加入作息字段
-- ============================================================
CREATE OR REPLACE FUNCTION fit_save_profile(
    tok UUID,
    p_height NUMERIC, p_weight NUMERIC, p_target_weight NUMERIC, p_age INTEGER,
    p_gender TEXT, p_activity_level TEXT, p_deficit INTEGER, p_time_available INTEGER,
    p_equipment TEXT, p_has_kitchen BOOLEAN,
    p_wake_time TEXT DEFAULT '08:00', p_sleep_time TEXT DEFAULT '23:00'
)
RETURNS JSON AS $$
DECLARE uid INTEGER;
BEGIN
    uid := fit_check_token(tok);
    INSERT INTO fit_profile (user_id, height, weight, target_weight, age, gender,
        activity_level, deficit, time_available, equipment, has_kitchen,
        wake_time, sleep_time, updated_at)
    VALUES (uid, p_height, p_weight, p_target_weight, p_age, p_gender,
        p_activity_level, p_deficit, p_time_available, p_equipment, p_has_kitchen,
        p_wake_time, p_sleep_time, NOW())
    ON CONFLICT (user_id) DO UPDATE SET
        height=EXCLUDED.height, weight=EXCLUDED.weight, target_weight=EXCLUDED.target_weight,
        age=EXCLUDED.age, gender=EXCLUDED.gender, activity_level=EXCLUDED.activity_level,
        deficit=EXCLUDED.deficit, time_available=EXCLUDED.time_available,
        equipment=EXCLUDED.equipment, has_kitchen=EXCLUDED.has_kitchen,
        wake_time=EXCLUDED.wake_time, sleep_time=EXCLUDED.sleep_time, updated_at=NOW();
    RETURN json_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 快捷食谱 CRUD
-- ============================================================
CREATE OR REPLACE FUNCTION fit_saved_meals_list(tok UUID)
RETURNS JSON AS $$
DECLARE uid INTEGER; result JSON;
BEGIN
    uid := fit_check_token(tok);
    SELECT json_agg(row_to_json(t)) INTO result FROM (
        SELECT id, name, calories, protein, carbs, fat FROM fit_saved_meals WHERE user_id=uid ORDER BY id
    ) t;
    RETURN COALESCE(result, '[]'::JSON);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION fit_saved_meals_add(tok UUID, p_name TEXT, p_cal NUMERIC, p_pro NUMERIC, p_carbs NUMERIC, p_fat NUMERIC)
RETURNS JSON AS $$
DECLARE uid INTEGER; new_id INTEGER;
BEGIN
    uid := fit_check_token(tok);
    INSERT INTO fit_saved_meals (user_id, name, calories, protein, carbs, fat)
    VALUES (uid, p_name, p_cal, p_pro, p_carbs, p_fat) RETURNING id INTO new_id;
    RETURN json_build_object('ok', true, 'id', new_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION fit_saved_meals_del(tok UUID, p_id INTEGER)
RETURNS JSON AS $$
DECLARE uid INTEGER;
BEGIN
    uid := fit_check_token(tok);
    DELETE FROM fit_saved_meals WHERE id=p_id AND user_id=uid;
    RETURN json_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 喝水
-- ============================================================
CREATE OR REPLACE FUNCTION fit_water_add(tok UUID, p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSON AS $$
DECLARE uid INTEGER; new_cups INTEGER;
BEGIN
    uid := fit_check_token(tok);
    INSERT INTO fit_water_logs (user_id, log_date, cups) VALUES (uid, p_date, 1);
    SELECT COUNT(*) INTO new_cups FROM fit_water_logs WHERE user_id=uid AND log_date=p_date;
    RETURN json_build_object('ok', true, 'total_cups', new_cups);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION fit_water_get(tok UUID, p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSON AS $$
DECLARE uid INTEGER; cnt INTEGER;
BEGIN
    uid := fit_check_token(tok);
    SELECT COUNT(*) INTO cnt FROM fit_water_logs WHERE user_id=uid AND log_date=p_date;
    RETURN json_build_object('date', p_date, 'cups', cnt);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION fit_water_del(tok UUID, p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSON AS $$
DECLARE uid INTEGER;
BEGIN
    uid := fit_check_token(tok);
    DELETE FROM fit_water_logs WHERE id = (
        SELECT id FROM fit_water_logs WHERE user_id=uid AND log_date=p_date ORDER BY id DESC LIMIT 1
    );
    RETURN json_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- 每日状态
-- ============================================================
CREATE OR REPLACE FUNCTION fit_state_save(tok UUID, p_date DATE, p_energy INTEGER, p_mood INTEGER, p_note TEXT DEFAULT NULL)
RETURNS JSON AS $$
DECLARE uid INTEGER;
BEGIN
    uid := fit_check_token(tok);
    INSERT INTO fit_daily_state (user_id, state_date, energy, mood, note)
    VALUES (uid, p_date, p_energy, p_mood, p_note)
    ON CONFLICT (user_id, state_date) DO UPDATE SET energy=EXCLUDED.energy, mood=EXCLUDED.mood, note=EXCLUDED.note;
    RETURN json_build_object('ok', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION fit_state_get(tok UUID, p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSON AS $$
DECLARE uid INTEGER; result JSON;
BEGIN
    uid := fit_check_token(tok);
    SELECT row_to_json(t) INTO result FROM (
        SELECT energy, mood, note FROM fit_daily_state WHERE user_id=uid AND state_date=p_date
    ) t;
    RETURN COALESCE(result, json_build_object('energy', 3, 'mood', 3, 'note', ''));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
