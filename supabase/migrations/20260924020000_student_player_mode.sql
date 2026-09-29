-- Student player identity, personal campaigns, and deterministic cosmetics.

create table if not exists public.player_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  display_name text not null check (length(btrim(display_name)) between 1 and 100),
  grade text,
  subject text,
  preferred_mode text not null default 'personal'
    check (preferred_mode in ('personal', 'school')),
  avatar_config jsonb not null default '{}'::jsonb
    check (jsonb_typeof(avatar_config) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.player_profiles is
  'One persistent game profile per auth user; school membership does not replace this identity.';
comment on column public.player_profiles.subject is
  'Free-form selected subject label; personal subjects are not tied to a school-scoped subject UUID.';
comment on column public.player_profiles.avatar_config is
  'Equipped cosmetic item keys by slot; changed through equip_player_cosmetic.';

create table if not exists public.solo_campaign_progress (
  player_profile_id uuid not null references public.player_profiles(id) on delete cascade,
  campaign_id text not null check (length(btrim(campaign_id)) > 0),
  node_id text not null check (length(btrim(node_id)) > 0),
  completed boolean not null default false,
  score integer not null default 0 check (score >= 0),
  stars smallint not null default 0 check (stars between 0 and 3),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (player_profile_id, campaign_id, node_id)
);

comment on table public.solo_campaign_progress is
  'Per-player completion state for personal campaign nodes.';

create table if not exists public.solo_campaign_node_catalog (
  node_id text primary key,
  required_nodes text[] not null default '{}',
  required_any_nodes text[] not null default '{}',
  created_at timestamptz not null default now()
);

insert into public.solo_campaign_node_catalog
  (node_id, required_nodes, required_any_nodes)
values
  ('first_step', '{}', '{}'),
  ('path_choice', '{first_step}', '{}'),
  ('branch_forest', '{path_choice}', '{}'),
  ('branch_ruins', '{path_choice}', '{}'),
  ('forest_lesson', '{branch_forest}', '{}'),
  ('ruins_lesson', '{branch_ruins}', '{}'),
  ('forest_treasure', '{forest_lesson}', '{}'),
  ('ruins_treasure', '{ruins_lesson}', '{}'),
  ('castle_gate', '{}', '{forest_treasure,ruins_treasure}'),
  ('castle_boss', '{castle_gate}', '{}')
on conflict (node_id) do nothing;

create table if not exists public.avatar_catalog (
  item_key text primary key,
  slot text not null check (slot in ('portrait', 'background', 'frame', 'effect', 'accessory')),
  display_name text not null,
  asset_key text not null unique,
  rarity text not null default 'common'
    check (rarity in ('common', 'uncommon', 'rare', 'epic')),
  required_completed_nodes integer not null default 0
    check (required_completed_nodes >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

comment on table public.avatar_catalog is
  'Shared cosmetic catalog; item keys and assets are stable across clients.';

insert into public.avatar_catalog
  (item_key, slot, display_name, asset_key, rarity, required_completed_nodes)
values
  ('portrait_nova', 'portrait', 'Nova', 'avatar/portrait_nova', 'common', 0),
  ('portrait_terra', 'portrait', 'Terra', 'avatar/portrait_terra', 'uncommon', 4),
  ('background_sky', 'background', 'Cielo', 'avatar/background_sky', 'common', 0),
  ('background_nebula', 'background', 'Nebulosa', 'avatar/background_nebula', 'rare', 8),
  ('frame_copper', 'frame', 'Cobre', 'avatar/frame_copper', 'common', 3),
  ('frame_prism', 'frame', 'Prisma', 'avatar/frame_prism', 'epic', 12),
  ('effect_spark', 'effect', 'Chispa', 'avatar/effect_spark', 'uncommon', 5),
  ('accessory_comet', 'accessory', 'Cometa', 'avatar/accessory_comet', 'rare', 10)
on conflict (item_key) do nothing;

create table if not exists public.player_cosmetics (
  player_profile_id uuid not null references public.player_profiles(id) on delete cascade,
  item_key text not null references public.avatar_catalog(item_key) on delete restrict,
  completed_nodes_at_award integer not null check (completed_nodes_at_award >= 0),
  awarded_at timestamptz not null default now(),
  primary key (player_profile_id, item_key)
);

comment on table public.player_cosmetics is
  'Cosmetic ownership ledger; clients can read their rows but only the award RPC can add ownership.';

-- All membership creation now goes through code-validating security-definer RPCs.
drop policy if exists "user insert own membership join" on public.memberships;

create index if not exists idx_solo_campaign_progress_completed
  on public.solo_campaign_progress (player_profile_id, completed)
  where completed = true;

alter table public.player_profiles enable row level security;
alter table public.solo_campaign_progress enable row level security;
alter table public.solo_campaign_node_catalog enable row level security;
alter table public.avatar_catalog enable row level security;
alter table public.player_cosmetics enable row level security;

drop policy if exists player_profiles_read_own on public.player_profiles;
create policy player_profiles_read_own on public.player_profiles
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists player_profiles_update_own on public.player_profiles;
create policy player_profiles_update_own on public.player_profiles
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and (
      preferred_mode = 'personal'
      or exists (
        select 1 from public.memberships m
        where m.user_id = (select auth.uid())
          and m.role = 'student'
          and m.status = 'active'
      )
    )
  );

drop policy if exists solo_progress_read_own on public.solo_campaign_progress;
create policy solo_progress_read_own on public.solo_campaign_progress
  for select to authenticated
  using (exists (
    select 1 from public.player_profiles pp
    where pp.id = solo_campaign_progress.player_profile_id
      and pp.user_id = (select auth.uid())
  ));

drop policy if exists solo_progress_insert_own on public.solo_campaign_progress;
drop policy if exists solo_progress_update_own on public.solo_campaign_progress;

drop policy if exists solo_campaign_nodes_read_authenticated
  on public.solo_campaign_node_catalog;
create policy solo_campaign_nodes_read_authenticated
  on public.solo_campaign_node_catalog for select to authenticated using (true);

drop policy if exists avatar_catalog_read_authenticated on public.avatar_catalog;
create policy avatar_catalog_read_authenticated on public.avatar_catalog
  for select to authenticated using (is_active = true);

drop policy if exists player_cosmetics_read_own on public.player_cosmetics;
create policy player_cosmetics_read_own on public.player_cosmetics
  for select to authenticated
  using (exists (
    select 1 from public.player_profiles pp
    where pp.id = player_cosmetics.player_profile_id
      and pp.user_id = (select auth.uid())
  ));

revoke all on table public.player_profiles, public.solo_campaign_progress,
  public.avatar_catalog, public.player_cosmetics,
  public.solo_campaign_node_catalog from public, anon, authenticated;
grant select on table public.player_profiles, public.avatar_catalog,
  public.player_cosmetics, public.solo_campaign_node_catalog to authenticated;
grant update (display_name, grade, subject, preferred_mode)
  on table public.player_profiles to authenticated;
grant select on table public.solo_campaign_progress to authenticated;

-- Newly onboarded school students get a player row, but an existing personal row is immutable here.
create or replace function public.ensure_student_player_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role = 'student' and new.status = 'active' then
    insert into public.player_profiles (user_id, display_name, preferred_mode)
    select
      new.user_id,
      coalesce(
        nullif(btrim(p.full_name), ''),
        nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''),
        nullif(btrim(u.raw_user_meta_data ->> 'name'), ''),
        nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
        'Estudiante'
      ),
      'school'
    from auth.users u
    left join public.profiles p on p.id = u.id
    where u.id = new.user_id
    on conflict (user_id) do nothing;
  end if;
  return new;
end;
$$;

revoke all on function public.ensure_student_player_profile() from public, anon, authenticated;
drop trigger if exists memberships_ensure_student_player_profile on public.memberships;
create trigger memberships_ensure_student_player_profile
  after insert or update of role, status on public.memberships
  for each row execute function public.ensure_student_player_profile();

-- Backfill all identities with at least one active student membership, without changing existing profiles.
insert into public.player_profiles (user_id, display_name, preferred_mode)
select distinct on (u.id)
  u.id,
  coalesce(
    nullif(btrim(p.full_name), ''),
    nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''),
    nullif(btrim(u.raw_user_meta_data ->> 'name'), ''),
    nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
    'Estudiante'
  ),
  'school'
from public.memberships m
join auth.users u on u.id = m.user_id
left join public.profiles p on p.id = u.id
where m.role = 'student' and m.status = 'active'
order by u.id, m.created_at
on conflict (user_id) do nothing;

-- Personal onboarding is independent; an existing personal profile remains idempotent and untouched.
create or replace function public.complete_personal_student_onboarding(
  p_display_name text,
  p_grade text,
  p_subject text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile_id uuid;
  v_mode text;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;
  if p_display_name is null or length(btrim(p_display_name)) not between 1 and 100 then
    raise exception 'display name must be between 1 and 100 characters';
  end if;
  if coalesce(length(nullif(btrim(p_grade), '')), 0) > 80
     or coalesce(length(nullif(btrim(p_subject), '')), 0) > 100 then
    raise exception 'grade or subject is too long';
  end if;

  perform 1 from auth.users where id = v_user_id for update;
  select id, preferred_mode into v_profile_id, v_mode
  from public.player_profiles where user_id = v_user_id;
  if found then
    if v_mode <> 'personal' then raise exception 'player profile already belongs to school mode'; end if;
    return v_profile_id;
  end if;

  if exists (select 1 from public.memberships where user_id = v_user_id) then
    raise exception 'account already has a school membership';
  end if;

  insert into public.player_profiles (user_id, display_name, grade, subject, preferred_mode)
  values (v_user_id, btrim(p_display_name), nullif(btrim(p_grade), ''), nullif(btrim(p_subject), ''), 'personal')
  returning id into v_profile_id;
  return v_profile_id;
end;
$$;

-- School-code joins reject any existing membership in that school; memberships in other schools are allowed.
create or replace function public.join_school_by_code(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_school_count integer;
  v_school_id uuid;
  v_membership_id uuid;
  v_membership_status text;
  v_name text;
  v_email text;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;
  if length(v_code) not between 3 and 64 then raise exception 'invalid school code'; end if;

  perform 1 from auth.users where id = v_user_id for update;

  select count(*) into v_school_count
  from public.schools s
  where upper(btrim(s.code)) = v_code;
  if v_school_count = 0 then raise exception 'school not found'; end if;
  if v_school_count <> 1 then raise exception 'school code is ambiguous'; end if;

  select s.id into v_school_id
  from public.schools s
  where upper(btrim(s.code)) = v_code;

  select m.status into v_membership_status
  from public.memberships m
  where m.user_id = v_user_id and m.school_id = v_school_id;
  if found then
    if v_membership_status = 'active' then raise exception 'membership already exists'; end if;
    raise exception 'membership is inactive';
  end if;

  insert into public.memberships (school_id, user_id, role, status)
  values (v_school_id, v_user_id, 'student', 'active')
  on conflict (school_id, user_id) do nothing
  returning id into v_membership_id;
  if v_membership_id is null then raise exception 'membership already exists'; end if;

  select
    coalesce(
      nullif(btrim(p.full_name), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''),
      nullif(btrim(u.raw_user_meta_data ->> 'name'), ''),
      nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
      'Estudiante'
    ),
    u.email
  into v_name, v_email
  from auth.users u
  left join public.profiles p on p.id = u.id
  where u.id = v_user_id;

  insert into public.student_profiles (
    school_id, membership_id, full_name, email, accessibility_preferences
  ) values (
    v_school_id, v_membership_id, v_name, v_email, '{}'::jsonb
  );

  return v_membership_id;
end;
$$;

-- Award only catalog items whose completed-node threshold the caller's own progress satisfies.
create or replace function public.award_player_cosmetics()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile_id uuid;
  v_completed_nodes integer;
  v_awarded integer;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;

  select id into v_profile_id
  from public.player_profiles where user_id = v_user_id;
  if v_profile_id is null then raise exception 'player profile not found'; end if;

  select count(*) into v_completed_nodes
  from public.solo_campaign_progress
  where player_profile_id = v_profile_id and completed = true;

  insert into public.player_cosmetics (player_profile_id, item_key, completed_nodes_at_award)
  select v_profile_id, c.item_key, v_completed_nodes
  from public.avatar_catalog c
  where c.is_active = true
    and c.required_completed_nodes <= v_completed_nodes
  on conflict (player_profile_id, item_key) do nothing;

  get diagnostics v_awarded = row_count;
  return v_awarded;
end;
$$;

-- Completion writes are server-validated; clients cannot mint arbitrary unlocked nodes.
create or replace function public.complete_solo_node(
  p_campaign_id text,
  p_node_id text,
  p_score integer default 0,
  p_stars smallint default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile_id uuid;
  v_node public.solo_campaign_node_catalog%rowtype;
  v_missing text;
  v_forbidden_branch boolean;
  v_unlocked integer;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;
  if p_campaign_id is null or length(btrim(p_campaign_id)) = 0 then
    raise exception 'campaign is required';
  end if;
  if p_score not between 0 and 100 or p_stars not between 0 and 3 then
    raise exception 'invalid score';
  end if;

  select id into v_profile_id
  from public.player_profiles
  where user_id = v_user_id
  for update;
  if v_profile_id is null then raise exception 'player profile not found'; end if;

  select * into v_node
  from public.solo_campaign_node_catalog
  where node_id = p_node_id;
  if not found then raise exception 'unknown campaign node'; end if;

  select prereq.node_id into v_missing
  from unnest(v_node.required_nodes) as prereq(node_id)
  where not exists (
    select 1 from public.solo_campaign_progress progress
    where progress.player_profile_id = v_profile_id
      and progress.campaign_id = p_campaign_id
      and progress.node_id = prereq.node_id
      and progress.completed = true
  )
  limit 1;
  if v_missing is not null then raise exception 'campaign node is still locked'; end if;

  if cardinality(v_node.required_any_nodes) > 0 and not exists (
    select 1 from public.solo_campaign_progress progress
    where progress.player_profile_id = v_profile_id
      and progress.campaign_id = p_campaign_id
      and progress.node_id = any(v_node.required_any_nodes)
      and progress.completed = true
  ) then
    raise exception 'campaign node is still locked';
  end if;

  if p_node_id in ('branch_forest', 'branch_ruins') then
    select exists (
      select 1 from public.solo_campaign_progress progress
      where progress.player_profile_id = v_profile_id
        and progress.campaign_id = p_campaign_id
        and progress.node_id in ('branch_forest', 'branch_ruins')
        and progress.completed = true
        and progress.node_id <> p_node_id
    ) into v_forbidden_branch;
    if v_forbidden_branch then raise exception 'a route branch is already selected'; end if;
  end if;

  insert into public.solo_campaign_progress as current_progress (
    player_profile_id, campaign_id, node_id, completed, score, stars,
    completed_at, created_at, updated_at
  ) values (
    v_profile_id, p_campaign_id, p_node_id, true, p_score, p_stars,
    now(), now(), now()
  )
  on conflict (player_profile_id, campaign_id, node_id) do update set
    completed = true,
    score = greatest(current_progress.score, excluded.score),
    stars = greatest(current_progress.stars, excluded.stars),
    completed_at = coalesce(current_progress.completed_at, excluded.completed_at),
    updated_at = now();

  v_unlocked := public.award_player_cosmetics();
  return jsonb_build_object(
    'campaign_id', p_campaign_id,
    'node_id', p_node_id,
    'cosmetics_unlocked', v_unlocked
  );
end;
$$;

-- Equipped items must be active catalog entries already owned by the caller.
create or replace function public.equip_player_cosmetic(p_item_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_profile_id uuid;
  v_slot text;
  v_avatar_config jsonb;
begin
  if v_user_id is null then raise exception 'authentication required'; end if;

  select id into v_profile_id
  from public.player_profiles where user_id = v_user_id;
  if v_profile_id is null then raise exception 'player profile not found'; end if;

  select c.slot into v_slot
  from public.avatar_catalog c
  join public.player_cosmetics pc on pc.item_key = c.item_key
  where c.item_key = p_item_key
    and c.is_active = true
    and pc.player_profile_id = v_profile_id;
  if v_slot is null then raise exception 'cosmetic is not owned or active'; end if;

  update public.player_profiles pp
  set avatar_config = jsonb_set(coalesce(pp.avatar_config, '{}'::jsonb), array[v_slot], to_jsonb(p_item_key), true),
      updated_at = now()
  where pp.id = v_profile_id
  returning avatar_config into v_avatar_config;

  return v_avatar_config;
end;
$$;

revoke all on function public.complete_personal_student_onboarding(text, text, text) from public, anon;
revoke all on function public.join_school_by_code(text) from public, anon;
revoke all on function public.award_player_cosmetics() from public, anon;
revoke all on function public.equip_player_cosmetic(text) from public, anon;
revoke all on function public.complete_solo_node(text, text, integer, smallint)
  from public, anon;
grant execute on function public.complete_personal_student_onboarding(text, text, text) to authenticated;
grant execute on function public.join_school_by_code(text) to authenticated;
grant execute on function public.award_player_cosmetics() to authenticated;
grant execute on function public.equip_player_cosmetic(text) to authenticated;
grant execute on function public.complete_solo_node(text, text, integer, smallint)
  to authenticated;
