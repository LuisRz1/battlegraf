-- Keep personal campaign IDs tied to the selected curriculum and stop cosmetic farming.

create or replace function public.personal_campaign_id(
  p_grade text,
  p_subject text
)
returns text
language sql
immutable
set search_path = public
as $$
  select 'starter_'
    || trim(both '_' from regexp_replace(
      lower(coalesce(nullif(btrim(p_grade), ''), '5to de primaria')),
      '[^a-z0-9]+', '_', 'g'
    ))
    || '_'
    || trim(both '_' from regexp_replace(
      lower(coalesce(nullif(btrim(p_subject), ''), 'General')),
      '[^a-z0-9]+', '_', 'g'
    ));
$$;

revoke all on function public.personal_campaign_id(text, text) from public, anon;
grant execute on function public.personal_campaign_id(text, text) to authenticated;

drop policy if exists player_profiles_update_own on public.player_profiles;
create policy player_profiles_update_own on public.player_profiles
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and (
      grade is null or grade in (
        '1ro de primaria', '2do de primaria', '3ro de primaria',
        '4to de primaria', '5to de primaria', '6to de primaria',
        '1ro de secundaria', '2do de secundaria', '3ro de secundaria',
        '4to de secundaria', '5to de secundaria'
      )
    )
    and (
      subject is null or subject in (
        'Matemática', 'Comunicación', 'Ciencia y tecnología', 'Historia', 'General'
      )
    )
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
      left(coalesce(
        nullif(btrim(p.full_name), ''),
        nullif(btrim(u.raw_user_meta_data ->> 'full_name'), ''),
        nullif(btrim(u.raw_user_meta_data ->> 'name'), ''),
        nullif(split_part(coalesce(u.email, ''), '@', 1), ''),
        'Estudiante'
      ), 100),
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
  if p_display_name is null or length(btrim(p_display_name)) = 0 then
    raise exception 'display name is required';
  end if;
  if p_grade is null or p_grade not in (
    '1ro de primaria', '2do de primaria', '3ro de primaria',
    '4to de primaria', '5to de primaria', '6to de primaria',
    '1ro de secundaria', '2do de secundaria', '3ro de secundaria',
    '4to de secundaria', '5to de secundaria'
  ) then raise exception 'invalid grade'; end if;
  if p_subject is null or p_subject not in (
    'Matemática', 'Comunicación', 'Ciencia y tecnología', 'Historia', 'General'
  ) then raise exception 'invalid subject'; end if;

  perform 1 from auth.users where id = v_user_id for update;
  select id, preferred_mode into v_profile_id, v_mode
  from public.player_profiles where user_id = v_user_id;
  if found then
    if v_mode <> 'personal' then
      raise exception 'player profile already belongs to school mode';
    end if;
    update public.player_profiles
    set display_name = left(btrim(p_display_name), 100),
        grade = p_grade,
        subject = p_subject,
        updated_at = now()
    where id = v_profile_id;
    return v_profile_id;
  end if;

  if exists (select 1 from public.memberships where user_id = v_user_id) then
    raise exception 'account already has a school membership';
  end if;

  insert into public.player_profiles (
    user_id, display_name, grade, subject, preferred_mode
  ) values (
    v_user_id, left(btrim(p_display_name), 100), p_grade, p_subject, 'personal'
  )
  returning id into v_profile_id;
  return v_profile_id;
end;
$$;

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

  select count(distinct node_id)::integer into v_completed_nodes
  from public.solo_campaign_progress
  where player_profile_id = v_profile_id
    and completed = true
    and node_id not in ('branch_forest', 'branch_ruins');

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
  v_grade text;
  v_subject text;
  v_expected_campaign text;
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

  select id, grade, subject
  into v_profile_id, v_grade, v_subject
  from public.player_profiles
  where user_id = v_user_id
  for update;
  if v_profile_id is null then raise exception 'player profile not found'; end if;

  v_expected_campaign := public.personal_campaign_id(v_grade, v_subject);
  if p_campaign_id <> v_expected_campaign then
    raise exception 'campaign does not match selected grade and subject';
  end if;

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

update public.avatar_catalog
set required_completed_nodes = case item_key
  when 'portrait_terra' then 2
  when 'background_nebula' then 5
  when 'frame_copper' then 2
  when 'frame_prism' then 6
  when 'effect_spark' then 3
  when 'accessory_comet' then 5
  else required_completed_nodes
end;

revoke all on function public.personal_campaign_id(text, text) from public, anon;
revoke all on function public.complete_personal_student_onboarding(text, text, text) from public, anon;
revoke all on function public.award_player_cosmetics() from public, anon;
revoke all on function public.complete_solo_node(text, text, integer, smallint) from public, anon;
grant execute on function public.personal_campaign_id(text, text) to authenticated;
grant execute on function public.complete_personal_student_onboarding(text, text, text) to authenticated;
grant execute on function public.award_player_cosmetics() to authenticated;
grant execute on function public.complete_solo_node(text, text, integer, smallint) to authenticated;
