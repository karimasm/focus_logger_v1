-- ============================================
-- GUIDED FLOWS MIGRATION
-- Makes flows fully dynamic and editable
-- ============================================

-- 1. Create guided_flows table (flow templates)
CREATE TABLE IF NOT EXISTS public.guided_flows (
  id text PRIMARY KEY,
  user_id uuid REFERENCES public.users(id),  -- NULL = system default, UUID = user custom
  name text NOT NULL,
  safety_window_id text,
  initial_prompt text,
  flow_type text NOT NULL DEFAULT 'routine',
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- 2. Create guided_flow_steps table
CREATE TABLE IF NOT EXISTS public.guided_flow_steps (
  id text PRIMARY KEY,
  flow_id text REFERENCES public.guided_flows(id) ON DELETE CASCADE NOT NULL,
  step_order integer NOT NULL,
  if_condition text NOT NULL,
  then_action text NOT NULL,
  activity_name text NOT NULL,
  description text,
  suggestions text,  -- pipe-separated list
  estimated_seconds integer,
  next_step_id text,
  is_optional boolean DEFAULT false,
  can_skip_to_end boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- 3. Enable RLS
ALTER TABLE public.guided_flows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guided_flow_steps ENABLE ROW LEVEL SECURITY;

-- 4. RLS Policies for guided_flows
-- Users can see system defaults (user_id IS NULL) and their own
CREATE POLICY "View system and own flows" ON public.guided_flows 
  FOR SELECT USING (user_id IS NULL OR user_id = auth.uid());

CREATE POLICY "Insert own flows" ON public.guided_flows 
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Update own flows" ON public.guided_flows 
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Delete own flows" ON public.guided_flows 
  FOR DELETE USING (user_id = auth.uid());

-- 5. RLS Policies for guided_flow_steps
CREATE POLICY "View steps of accessible flows" ON public.guided_flow_steps 
  FOR SELECT USING (
    flow_id IN (SELECT id FROM public.guided_flows WHERE user_id IS NULL OR user_id = auth.uid())
  );

CREATE POLICY "Insert steps to own flows" ON public.guided_flow_steps 
  FOR INSERT WITH CHECK (
    flow_id IN (SELECT id FROM public.guided_flows WHERE user_id = auth.uid())
  );

CREATE POLICY "Update steps of own flows" ON public.guided_flow_steps 
  FOR UPDATE USING (
    flow_id IN (SELECT id FROM public.guided_flows WHERE user_id = auth.uid())
  );

CREATE POLICY "Delete steps of own flows" ON public.guided_flow_steps 
  FOR DELETE USING (
    flow_id IN (SELECT id FROM public.guided_flows WHERE user_id = auth.uid())
  );

-- 6. Indexes
CREATE INDEX IF NOT EXISTS idx_guided_flows_user ON public.guided_flows(user_id);
CREATE INDEX IF NOT EXISTS idx_guided_flows_type ON public.guided_flows(flow_type);
CREATE INDEX IF NOT EXISTS idx_guided_flow_steps_flow ON public.guided_flow_steps(flow_id);
CREATE INDEX IF NOT EXISTS idx_guided_flow_steps_order ON public.guided_flow_steps(flow_id, step_order);

-- ============================================
-- SEED DEFAULT FLOWS (System defaults, user_id = NULL)
-- ============================================

-- Subuh Flow
INSERT INTO public.guided_flows (id, user_id, name, safety_window_id, initial_prompt, flow_type) VALUES
('subuh_flow', NULL, 'Subuh Routine', 'window_subuh', 'Time for Subuh prayer', 'prayer')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.guided_flow_steps (id, flow_id, step_order, if_condition, then_action, activity_name, description, suggestions, estimated_seconds, is_optional, can_skip_to_end) VALUES
('subuh_pray', 'subuh_flow', 1, 'time is in Subuh window', 'pray Subuh', 'Sholat Subuh', 'Perform Subuh prayer', 'Wudhu|2 rakaat sunnah|2 rakaat fardhu', 600, false, false),
('subuh_dzikir', 'subuh_flow', 2, 'you finished praying', 'do morning dzikir', 'Dzikir Pagi', 'Morning remembrance after Subuh', 'Ayat Kursi|Tasbih|Istighfar', 600, false, false),
('subuh_move', 'subuh_flow', 3, 'you finished dzikir', 'move your body', 'Morning Movement', 'Light exercise or stretching', 'Stretching|Light walk|Yoga', 900, true, true)
ON CONFLICT (id) DO NOTHING;

-- Dzuhur Flow
INSERT INTO public.guided_flows (id, user_id, name, safety_window_id, initial_prompt, flow_type) VALUES
('dzuhur_flow', NULL, 'Dzuhur Routine', 'window_dzuhur', 'Time for Dzuhur prayer', 'prayer')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.guided_flow_steps (id, flow_id, step_order, if_condition, then_action, activity_name, description, suggestions, estimated_seconds, is_optional, can_skip_to_end) VALUES
('dzuhur_prep', 'dzuhur_flow', 1, 'time is in Dzuhur window', 'prepare for prayer', 'Prepare Prayer', 'Wudhu and mental preparation', 'Wudhu|Find quiet space', 300, false, false),
('dzuhur_pray', 'dzuhur_flow', 2, 'you are ready', 'pray Dzuhur', 'Sholat Dzuhur', 'Perform Dzuhur prayer', '4 rakaat sunnah|4 rakaat fardhu|2 rakaat sunnah', 900, false, false),
('dzuhur_rest', 'dzuhur_flow', 3, 'you finished praying', 'take a short rest', 'Midday Rest', 'Brief rest or power nap', 'Qaylulah|Relax|Hydrate', 900, true, true)
ON CONFLICT (id) DO NOTHING;

-- Ashar Flow
INSERT INTO public.guided_flows (id, user_id, name, safety_window_id, initial_prompt, flow_type) VALUES
('ashar_flow', NULL, 'Ashar Routine', 'window_ashar', 'Time for Ashar prayer', 'prayer')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.guided_flow_steps (id, flow_id, step_order, if_condition, then_action, activity_name, description, suggestions, estimated_seconds, is_optional, can_skip_to_end) VALUES
('ashar_pray', 'ashar_flow', 1, 'time is in Ashar window', 'pray Ashar', 'Sholat Ashar', 'Perform Ashar prayer', 'Wudhu|4 rakaat fardhu', 600, false, false),
('ashar_reflect', 'ashar_flow', 2, 'you finished praying', 'reflect on your day', 'Afternoon Reflection', 'Quick review of day progress', 'What did I accomplish?|What''s left?', 300, true, true)
ON CONFLICT (id) DO NOTHING;

-- Magrib Flow
INSERT INTO public.guided_flows (id, user_id, name, safety_window_id, initial_prompt, flow_type) VALUES
('magrib_flow', NULL, 'Magrib Routine', 'window_magrib', 'Time for Magrib prayer', 'prayer')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.guided_flow_steps (id, flow_id, step_order, if_condition, then_action, activity_name, description, suggestions, estimated_seconds, is_optional, can_skip_to_end) VALUES
('magrib_pray', 'magrib_flow', 1, 'time is in Magrib window', 'pray Magrib', 'Sholat Magrib', 'Perform Magrib prayer', 'Wudhu|3 rakaat fardhu|2 rakaat sunnah', 600, false, false),
('magrib_quran', 'magrib_flow', 2, 'you finished praying', 'read Quran', 'Tilawah', 'Read or listen to Quran', '1 page|1 juz|Listen', 900, false, false),
('magrib_family', 'magrib_flow', 3, 'you finished Quran', 'spend time with family', 'Family Time', 'Quality time with loved ones', 'Dinner together|Talk|Play', 1800, true, true)
ON CONFLICT (id) DO NOTHING;

-- Isya Flow
INSERT INTO public.guided_flows (id, user_id, name, safety_window_id, initial_prompt, flow_type) VALUES
('isya_flow', NULL, 'Isya Routine', 'window_isya', 'Time for Isya prayer', 'prayer')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.guided_flow_steps (id, flow_id, step_order, if_condition, then_action, activity_name, description, suggestions, estimated_seconds, is_optional, can_skip_to_end) VALUES
('isya_pray', 'isya_flow', 1, 'time is in Isya window', 'pray Isya', 'Sholat Isya', 'Perform Isya prayer', 'Wudhu|4 rakaat fardhu|2 rakaat sunnah', 600, false, false),
('isya_witr', 'isya_flow', 2, 'you finished Isya', 'pray Witr', 'Sholat Witr', 'Closing night prayer', '1-11 rakaat|Doa qunut', 600, true, true)
ON CONFLICT (id) DO NOTHING;

-- Sleep Flow
INSERT INTO public.guided_flows (id, user_id, name, safety_window_id, initial_prompt, flow_type) VALUES
('sleep_flow', NULL, 'Sleep Discipline', 'window_sleep', 'Time to prepare for sleep', 'sleep')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.guided_flow_steps (id, flow_id, step_order, if_condition, then_action, activity_name, description, suggestions, estimated_seconds, is_optional, can_skip_to_end) VALUES
('sleep_prepare', 'sleep_flow', 1, 'time is in Sleep window', 'prepare for tomorrow', 'Prepare Tomorrow', 'Clear desk, layout items, mental unload', 'Clear desk|Set out clothes|Pack bag', 600, false, false),
('sleep_winddown', 'sleep_flow', 2, 'you prepared everything', 'wind down', 'Wind-Down', 'Light reflection, calm your mind', 'Deep breathing|Light reading|Gratitude', 600, false, false),
('sleep_actual', 'sleep_flow', 3, 'you are calm', 'go to sleep', 'Sleeping', 'Rest until 04:30 or when you wake up', NULL, 18000, false, true),
('sleep_tahajud', 'sleep_flow', 4, 'you woke up before Subuh', 'tahajud prayer', 'Tahajud', 'Night prayer if you wake up before Subuh', 'Wudhu|2-8 rakaat|Doa', 900, true, false)
ON CONFLICT (id) DO NOTHING;

-- Distraction Recovery Flow
INSERT INTO public.guided_flows (id, user_id, name, safety_window_id, initial_prompt, flow_type) VALUES
('distraction_recovery', NULL, 'Distraction Recovery', NULL, 'You were distracted. Let''s get back on track.', 'recovery')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.guided_flow_steps (id, flow_id, step_order, if_condition, then_action, activity_name, description, suggestions, estimated_seconds, is_optional, can_skip_to_end) VALUES
('recovery_recall', 'distraction_recovery', 1, 'you were distracted', 'recall what you were doing', 'Focus Recovery', 'Remember your task before distraction', 'What were you working on?|How far did you get?', 60, false, false),
('recovery_restart', 'distraction_recovery', 2, 'you remember your task', 'restart with intention', 'Restart Work', 'Begin again with clear focus', 'Set timer|Remove distractions|Start', 60, false, true)
ON CONFLICT (id) DO NOTHING;
