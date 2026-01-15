-- Communication Tools – Supabase Data Storage (No RLS / No Policies)
-- Table for case-based communication messages
create table if not exists public.case_messages (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references public.reports (id) on delete cascade,
  sender_id uuid not null references public.users (id) on delete cascade,
  sender_role text not null check (sender_role in ('teacher', 'counselor', 'dean', 'admin')),
  message text not null check (char_length(message) <= 4000),
  created_at timestamp with time zone not null default now()
);

-- Helpful index for lookups by case
create index if not exists idx_case_messages_case_id_created_at
  on public.case_messages (case_id, created_at);

-- RLS explicitly disabled (application-level access only)
alter table public.case_messages disable row level security;

