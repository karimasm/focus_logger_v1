-- Supabase Schema for Focus Logger Sync
-- USER-SCOPED GLOBAL ACTIVITY MODEL
-- All data belongs to user_id, device_id is audit only

-- 1. Activities Table (USER-SCOPED)
create table if not exists public.activities (
  id uuid not null primary key,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  
  -- USER-SCOPED: user_id is the primary owner
  user_id uuid references auth.users(id),
  
  -- AUDIT: device_id shows which device created/modified (not for queries)
  device_id text,
  
  name text not null,
  category text,
  start_time timestamptz not null,
  end_time timestamptz,
  is_auto_generated integer default 0,
  is_running integer default 0,
  is_paused integer default 0,
  paused_duration_seconds integer default 0,
  paused_at timestamptz,
  source text,
  guided_flow_id text,
  chain_context text
);

-- 2. Pause Logs Table (USER-SCOPED)
create table if not exists public.pause_logs (
  id uuid not null primary key,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  user_id uuid,
  device_id text,
  activity_id uuid not null references public.activities(id) on delete cascade,
  pause_time timestamptz not null,
  resume_time timestamptz,
  reason text not null,
  custom_reason text
);

-- 3. Guided Flow Logs Table (USER-SCOPED)
create table if not exists public.guided_flow_logs (
  id uuid not null primary key,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  user_id uuid,
  device_id text,
  flow_id text not null,
  flow_name text not null,
  triggered_at timestamptz not null,
  completed_at timestamptz,
  steps_completed integer default 0,
  total_steps integer not null,
  was_abandoned integer default 0,
  was_missed integer default 0,
  was_skipped_haid integer default 0
);

-- 4. Memo Entries Table (USER-SCOPED)
create table if not exists public.memo_entries (
  id uuid not null primary key,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  user_id uuid,
  device_id text,
  activity_id uuid not null references public.activities(id) on delete cascade,
  timestamp timestamptz not null,
  text text not null,
  source text default 'manual'
);

-- 5. Ad-Hoc Tasks Table (USER-SCOPED)
create table if not exists public.adhoc_tasks (
  id uuid not null primary key,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  user_id uuid,
  device_id text,
  title text not null,
  description text,
  execution_state integer default 0,
  started_at timestamptz,
  completed_at timestamptz,
  linked_activity_id uuid references public.activities(id) on delete set null,
  sort_order integer default 0
);

-- 6. Haid Mode Table (USER-SCOPED)
create table if not exists public.haid_mode (
  id uuid not null primary key,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  user_id uuid,
  device_id text,
  is_active integer default 0,
  cycle_start_at timestamptz,
  last_prompt_date timestamptz
);

-- Enable Row Level Security (RLS)
alter table public.activities enable row level security;
alter table public.pause_logs enable row level security;
alter table public.guided_flow_logs enable row level security;
alter table public.memo_entries enable row level security;
alter table public.adhoc_tasks enable row level security;
alter table public.haid_mode enable row level security;

-- USER-BASED RLS POLICIES
-- Users can only access their own data
create policy "Users own activities" on public.activities
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users own pause_logs" on public.pause_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users own guided_flow_logs" on public.guided_flow_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users own memo_entries" on public.memo_entries
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users own adhoc_tasks" on public.adhoc_tasks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "Users own haid_mode" on public.haid_mode
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- CONSTRAINT: Only 1 running activity per user
-- This enforces global single-session per user across all devices
create unique index if not exists unique_running_per_user 
  on public.activities(user_id) 
  where is_running = 1;

-- Indexes for better query performance
create index if not exists idx_activities_updated_at on public.activities(updated_at);
create index if not exists idx_activities_user_running on public.activities(user_id, is_running);
create index if not exists idx_pause_logs_updated_at on public.pause_logs(updated_at);
create index if not exists idx_pause_logs_user on public.pause_logs(user_id);
create index if not exists idx_guided_flow_logs_updated_at on public.guided_flow_logs(updated_at);
create index if not exists idx_guided_flow_logs_user on public.guided_flow_logs(user_id);
create index if not exists idx_memo_entries_updated_at on public.memo_entries(updated_at);
create index if not exists idx_memo_entries_user on public.memo_entries(user_id);
create index if not exists idx_adhoc_tasks_updated_at on public.adhoc_tasks(updated_at);
create index if not exists idx_adhoc_tasks_user on public.adhoc_tasks(user_id);
create index if not exists idx_haid_mode_updated_at on public.haid_mode(updated_at);
create index if not exists idx_haid_mode_user on public.haid_mode(user_id);
