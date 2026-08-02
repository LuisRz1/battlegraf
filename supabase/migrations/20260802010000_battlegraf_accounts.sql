-- BattleGraph: cuentas institucionales, planes y aislamiento por colegio.
-- Ejecutar desde Supabase SQL Editor o mediante Supabase CLI.

create extension if not exists pgcrypto;

create table if not exists public.plans (
  slug text primary key check (slug in ('explorador', 'aula', 'colegio', 'red')),
  name text not null,
  student_limit integer not null check (student_limit > 0),
  ai_credits_monthly integer not null default 0 check (ai_credits_monthly >= 0),
  features jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

insert into public.plans (slug, name, student_limit, ai_credits_monthly, features)
values
  ('explorador', 'Explorador', 30, 0, '{"ai":false,"uploads":false,"post_battle_summary":false,"teacher_chat":false,"student_chat":false}'),
  ('aula', 'Aula', 150, 400, '{"ai":true,"uploads":true,"question_generation":true,"post_battle_summary":false,"teacher_chat":false,"student_chat":false}'),
  ('colegio', 'Colegio', 600, 2500, '{"ai":true,"uploads":true,"question_generation":true,"class_generation":true,"answer_review":true,"teacher_chat":true,"post_battle_summary":true,"student_chat":false}'),
  ('red', 'Red Educativa', 2000, 15000, '{"ai":true,"uploads":true,"question_generation":true,"class_generation":true,"answer_review":true,"teacher_chat":true,"student_chat":true,"post_battle_summary":true,"adaptive_support":true,"multi_campus":true,"sso":true}')
on conflict (slug) do update set
  name = excluded.name,
  student_limit = excluded.student_limit,
  ai_credits_monthly = excluded.ai_credits_monthly,
  features = excluded.features;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.schools (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text unique,
  region text,
  city text,
  onboarding_complete boolean not null default false,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.memberships (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','director','subdirector','coordinator','tutor','teacher','student')),
  status text not null default 'active' check (status in ('invited','active','suspended')),
  created_at timestamptz not null default now(),
  unique (school_id, user_id)
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null unique references public.schools(id) on delete cascade,
  plan_slug text not null references public.plans(slug),
  status text not null default 'active' check (status in ('trialing','active','past_due','canceled')),
  student_limit integer not null,
  ai_credits_monthly integer not null default 0,
  ai_credits_used integer not null default 0,
  current_period_start timestamptz not null default now(),
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.student_profiles (
  id uuid primary key default gen_random_uuid(),
  school_id uuid not null references public.schools(id) on delete cascade,
  membership_id uuid references public.memberships(id) on delete set null,
  full_name text not null,
  section_id uuid,
  accessibility_preferences jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name'),
    coalesce(new.raw_user_meta_data ->> 'avatar_url', new.raw_user_meta_data ->> 'picture')
  )
  on conflict (id) do update set
    email = excluded.email,
    full_name = excluded.full_name,
    avatar_url = excluded.avatar_url,
    updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert or update on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.bootstrap_institution_account(p_plan_slug text default 'explorador')
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_school_id uuid;
  v_plan public.plans%rowtype;
  v_name text;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;

  select school_id into v_school_id
  from public.memberships
  where user_id = v_user_id and role = 'owner'
  order by created_at asc limit 1;

  if v_school_id is not null then return v_school_id; end if;

  select * into v_plan from public.plans where slug = p_plan_slug;
  if not found then select * into v_plan from public.plans where slug = 'explorador'; end if;

  select coalesce(nullif(full_name, ''), split_part(coalesce(email, 'BattleGraph'), '@', 1))
  into v_name from public.profiles where id = v_user_id;

  insert into public.schools (name, created_by)
  values ('Institución de ' || coalesce(v_name, 'BattleGraph'), v_user_id)
  returning id into v_school_id;

  insert into public.memberships (school_id, user_id, role)
  values (v_school_id, v_user_id, 'owner');

  insert into public.subscriptions (school_id, plan_slug, status, student_limit, ai_credits_monthly)
  values (
    v_school_id,
    v_plan.slug,
    case when v_plan.slug = 'explorador' then 'active' else 'trialing' end,
    v_plan.student_limit,
    v_plan.ai_credits_monthly
  );

  return v_school_id;
end;
$$;

alter table public.plans enable row level security;
alter table public.profiles enable row level security;
alter table public.schools enable row level security;
alter table public.memberships enable row level security;
alter table public.subscriptions enable row level security;
alter table public.student_profiles enable row level security;

create or replace function public.is_school_member(p_school_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.memberships
    where school_id = p_school_id and user_id = auth.uid() and status = 'active'
  );
$$;

create or replace function public.is_school_admin(p_school_id uuid)
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1 from public.memberships
    where school_id = p_school_id
      and user_id = auth.uid()
      and role in ('owner','director','subdirector','coordinator')
      and status = 'active'
  );
$$;

create policy "plans are publicly readable" on public.plans for select using (true);
create policy "users read own profile" on public.profiles for select using (id = auth.uid());
create policy "users update own profile" on public.profiles for update using (id = auth.uid());
create policy "members read their schools" on public.schools for select using (public.is_school_member(id));
create policy "school administrators update school" on public.schools for update using (public.is_school_admin(id));
create policy "members read memberships" on public.memberships for select using (
  user_id = auth.uid() or public.is_school_admin(school_id)
);
create policy "members read subscriptions" on public.subscriptions for select using (public.is_school_member(school_id));
create policy "staff read student profiles" on public.student_profiles for select using (public.is_school_admin(school_id));

grant execute on function public.bootstrap_institution_account(text) to authenticated;
grant execute on function public.is_school_member(uuid) to authenticated;
grant execute on function public.is_school_admin(uuid) to authenticated;
revoke all on function public.bootstrap_institution_account(text) from anon;
revoke all on function public.is_school_member(uuid) from anon;
revoke all on function public.is_school_admin(uuid) from anon;
