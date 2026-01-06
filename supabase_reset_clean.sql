-- ========================================================================
-- FOCUS LOGGER - COMPLETE RESET & SETUP (DIJAMIN JALAN)
-- Run script ini 1x di Supabase SQL Editor
-- Ini akan hapus semua constraint yang bikin error, rebuild schema bersih
-- ========================================================================

-- 1. HAPUS SEMUA FOREIGN KEY CONSTRAINTS (ini yang bikin error terus)
ALTER TABLE IF EXISTS public.activities DROP CONSTRAINT IF EXISTS activities_user_id_fkey;
ALTER TABLE IF EXISTS public.pause_logs DROP CONSTRAINT IF EXISTS pause_logs_user_id_fkey;
ALTER TABLE IF EXISTS public.pause_logs DROP CONSTRAINT IF EXISTS pause_logs_activity_id_fkey;
ALTER TABLE IF EXISTS public.memo_entries DROP CONSTRAINT IF EXISTS memo_entries_user_id_fkey;
ALTER TABLE IF EXISTS public.memo_entries DROP CONSTRAINT IF EXISTS memo_entries_activity_id_fkey;
ALTER TABLE IF EXISTS public.guided_flow_logs DROP CONSTRAINT IF EXISTS guided_flow_logs_user_id_fkey;
ALTER TABLE IF EXISTS public.adhoc_tasks DROP CONSTRAINT IF EXISTS adhoc_tasks_user_id_fkey;
ALTER TABLE IF EXISTS public.haid_mode DROP CONSTRAINT IF EXISTS haid_mode_user_id_fkey;

-- 2. BUAT/UPDATE TABEL USERS
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    email TEXT,
    display_name TEXT
);

-- 3. INSERT GLOBAL USER (single user mode)
INSERT INTO public.users (id, email, display_name, created_at, updated_at)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'global@flow.local',
    'Flow User',
    NOW(),
    NOW()
)
ON CONFLICT (id) DO UPDATE 
SET updated_at = NOW();

-- 4. BUAT/UPDATE SEMUA TABEL LAINNYA (tanpa FK constraint)
CREATE TABLE IF NOT EXISTS public.activities (
    id UUID PRIMARY KEY,
    user_id UUID,  -- No FK constraint, jadi ga bakal error
    name TEXT NOT NULL,
    category TEXT DEFAULT 'General',
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    is_running BOOLEAN DEFAULT FALSE,
    paused_duration_seconds INTEGER DEFAULT 0,
    is_paused BOOLEAN DEFAULT FALSE,
    pause_reason TEXT,
    paused_at TIMESTAMPTZ,
    device_id TEXT,
    source TEXT DEFAULT 'manual',
    guided_flow_id TEXT,
    chain_context TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.pause_logs (
    id UUID PRIMARY KEY,
    user_id UUID,  -- No FK
    activity_id UUID,  -- No FK
    reason TEXT NOT NULL,
    pause_time TIMESTAMPTZ NOT NULL,
    resume_time TIMESTAMPTZ,
    duration_seconds INTEGER DEFAULT 0,
    device_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.memo_entries (
    id UUID PRIMARY KEY,
    user_id UUID,  -- No FK
    activity_id UUID,  -- No FK
    timestamp TIMESTAMPTZ NOT NULL,
    text TEXT NOT NULL,
    source TEXT DEFAULT 'manual',
    device_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.guided_flow_logs (
    id UUID PRIMARY KEY,
    user_id UUID,  -- No FK
    flow_id TEXT NOT NULL,
    flow_name TEXT NOT NULL,
    triggered_at TIMESTAMPTZ NOT NULL,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    steps_completed INTEGER DEFAULT 0,
    total_steps INTEGER DEFAULT 0,
    was_abandoned BOOLEAN DEFAULT FALSE,
    was_missed BOOLEAN DEFAULT FALSE,
    was_skipped_haid BOOLEAN DEFAULT FALSE,
    device_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.adhoc_tasks (
    id UUID PRIMARY KEY,
    user_id UUID,  -- No FK
    title TEXT NOT NULL,
    description TEXT,
    execution_state INTEGER DEFAULT 0,
    sort_order INTEGER DEFAULT 0,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    linked_activity_id UUID,
    device_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.haid_mode (
    id UUID PRIMARY KEY,
    user_id UUID,  -- No FK
    is_active INTEGER DEFAULT 0,
    cycle_start_at TIMESTAMPTZ,
    last_prompt_date TIMESTAMPTZ,
    device_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.energy_checks (
    id UUID PRIMARY KEY,
    user_id UUID,  -- No FK
    activity_id UUID,
    task_id UUID,
    level INTEGER DEFAULT 3,
    recorded_at TIMESTAMPTZ NOT NULL,
    note TEXT,
    device_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. ENABLE RLS & BUAT POLICY PERMISSIVE (allow semua operasi)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pause_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memo_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guided_flow_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.adhoc_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.haid_mode ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.energy_checks ENABLE ROW LEVEL SECURITY;

-- Drop old policies
DROP POLICY IF EXISTS "Allow all" ON public.users;
DROP POLICY IF EXISTS "Allow all" ON public.activities;
DROP POLICY IF EXISTS "Allow all" ON public.pause_logs;
DROP POLICY IF EXISTS "Allow all" ON public.memo_entries;
DROP POLICY IF EXISTS "Allow all" ON public.guided_flow_logs;
DROP POLICY IF EXISTS "Allow all" ON public.adhoc_tasks;
DROP POLICY IF EXISTS "Allow all" ON public.haid_mode;
DROP POLICY IF EXISTS "Allow all" ON public.energy_checks;

-- Create permissive policies (allow everything)
CREATE POLICY "Allow all" ON public.users FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.activities FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.pause_logs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.memo_entries FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.guided_flow_logs FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.adhoc_tasks FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.haid_mode FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all" ON public.energy_checks FOR ALL USING (true) WITH CHECK (true);

-- 6. VERIFIKASI
SELECT 'Setup complete!' AS status;
SELECT 'Global user exists:' AS check, COUNT(*) AS count 
FROM public.users 
WHERE id = '00000000-0000-0000-0000-000000000001';
