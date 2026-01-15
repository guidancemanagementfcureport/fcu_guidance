-- Backup Jobs Table
create table if not exists backup_jobs (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references auth.users(id),
  backup_type text, -- full, reports_only, messages_only, etc.
  description text,
  created_at timestamp with time zone default now()
);

-- Backup Records Table
create table if not exists backup_records (
  id uuid primary key default gen_random_uuid(),
  backup_job_id uuid references backup_jobs(id) on delete cascade,
  table_name text,
  record_data jsonb,
  created_at timestamp with time zone default now()
);

-- RLS Policies (Admin Only)
alter table backup_jobs enable row level security;
alter table backup_records enable row level security;

create policy "Admins can do everything with backup_jobs"
on backup_jobs for all
using (
  auth.uid() in (
    select id from public.users where role = 'admin'
  )
);

create policy "Admins can do everything with backup_records"
on backup_records for all
using (
  auth.uid() in (
    select id from public.users where role = 'admin'
  )
);
