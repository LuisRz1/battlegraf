-- The class policies predate this schema-hardening pass but RLS was not enabled.
alter table public.classes enable row level security;
