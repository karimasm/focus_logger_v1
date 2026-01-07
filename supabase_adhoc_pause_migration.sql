-- Migration: Add pause/alarm fields to adhoc_tasks table
-- Run this in Supabase SQL Editor

-- Add pause state columns
ALTER TABLE adhoc_tasks ADD COLUMN IF NOT EXISTS is_paused BOOLEAN DEFAULT FALSE;
ALTER TABLE adhoc_tasks ADD COLUMN IF NOT EXISTS paused_at TIMESTAMPTZ;
ALTER TABLE adhoc_tasks ADD COLUMN IF NOT EXISTS paused_duration_seconds INTEGER DEFAULT 0;

-- Add alarm columns
ALTER TABLE adhoc_tasks ADD COLUMN IF NOT EXISTS alarm_time TIMESTAMPTZ;
ALTER TABLE adhoc_tasks ADD COLUMN IF NOT EXISTS alarm_triggered BOOLEAN DEFAULT FALSE;

-- Fix user_id constraint - make it nullable or set default
-- Option 1: Make user_id nullable (if it was NOT NULL before)
ALTER TABLE adhoc_tasks ALTER COLUMN user_id DROP NOT NULL;

-- Option 2: Or update existing null user_ids to the current user
-- UPDATE adhoc_tasks SET user_id = auth.uid() WHERE user_id IS NULL;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';
