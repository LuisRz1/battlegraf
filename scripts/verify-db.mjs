import postgres from "postgres";

const connectionString =
  process.env.POSTGRES_URL_NON_POOLING ?? process.env.POSTGRES_URL;
const requiredMigrations = [
  "20260913090000_bot_difficulty.sql",
  "20260913091000_report_config.sql",
  "20260913100000_assignment_instructions.sql",
  "20260924010000_academic_traceability_hardening.sql",
  "20260924020000_student_player_mode.sql",
  "20260924030000_classes_rls_activation.sql",
  "20260924040000_solo_progress_integrity.sql",
  "20260924050000_student_onboarding_integrity.sql",
  "20260924060000_canonical_class_enrollments.sql",
  "20260924070000_enrollment_identity_consistency.sql",
  "20260924080000_reject_conflicting_enrollment_identity.sql",
];

if (!connectionString) {
  throw new Error("Falta POSTGRES_URL_NON_POOLING o POSTGRES_URL.");
}

const sql = postgres(connectionString, {
  max: 1,
  ssl: "require",
  connect_timeout: 20,
});

try {
  const tables = await sql`
		select table_name
		from information_schema.tables
		where table_schema = 'public'
		  and table_name in (
			'plans', 'profiles', 'schools', 'memberships',
		  'subscriptions', 'student_profiles', 'academic_years',
		  'subjects', 'sections', 'section_subjects', 'clans',
		  'learning_materials', 'question_bank', 'school_settings',
		  'attendance_records', 'grade_items', 'student_grades',
		  'student_observations', 'subject_teachers', 'staff_profiles',
		  'academic_periods', 'assignments', 'assignment_submissions',
		  'battle_results', 'classes',
		  'class_enrollments', 'player_profiles', 'solo_campaign_progress',
		  'solo_campaign_node_catalog', 'avatar_catalog', 'player_cosmetics'
		  )
		order by table_name
	`;
  const plans = await sql`
		select slug, student_limit, ai_credits_monthly
		from public.plans
		order by student_limit
	`;
  const rls = await sql`
		select tablename
		from pg_tables
		where schemaname = 'public'
		  and rowsecurity = true
		  and tablename in (
			'plans', 'profiles', 'schools', 'memberships',
		  'subscriptions', 'student_profiles', 'academic_years',
		  'subjects', 'sections', 'section_subjects', 'clans',
		  'learning_materials', 'question_bank', 'school_settings',
		  'attendance_records', 'grade_items', 'student_grades',
		  'student_observations', 'subject_teachers', 'staff_profiles',
		  'academic_periods', 'assignments', 'assignment_submissions',
		  'battle_results', 'classes',
		  'class_enrollments', 'player_profiles', 'solo_campaign_progress',
		  'solo_campaign_node_catalog', 'avatar_catalog', 'player_cosmetics'
		  )
		order by tablename
	`;
  const scopedPolicies = await sql`
		select tablename, policyname, cmd, qual, with_check
		from pg_policies
		where schemaname = 'public'
		  and tablename in (
		    'classes', 'memberships', 'staff_profiles', 'student_profiles',
		    'player_profiles', 'solo_campaign_progress', 'avatar_catalog', 'player_cosmetics'
		  )
		order by tablename, policyname
	`;

  const trials = await sql`
		select plan_slug, trial_plan_slug, status, trial_ends_at
		from public.subscriptions
		order by created_at desc
		limit 5
	`;
  const seeded = await sql`
		select s.id, s.name,
			(select count(*)::int from public.sections x where x.school_id = s.id) as sections,
			(select count(*)::int from public.subjects x where x.school_id = s.id) as subjects,
			(select count(*)::int from public.question_bank x where x.school_id = s.id) as questions
		from public.schools s
		order by s.created_at desc
		limit 5
	`;
  const playerMode = await sql`
		select
		  to_regprocedure('public.complete_personal_student_onboarding(text,text,text)') is not null as personal_onboarding,
		  to_regprocedure('public.complete_mobile_onboarding(text,text,text,text,text)') is not null as web_school_onboarding,
		  to_regprocedure('public.join_school_by_code(text)') is not null as join_school,
		  to_regprocedure('public.link_or_create_student_profile(uuid,uuid,text,text)') is not null as roster_profile_linking,
		  to_regprocedure('public.enroll_student_by_code(text)') is not null as class_enrollment,
		  position(
		    'enrollment identity is inconsistent' in
		    pg_get_functiondef(to_regprocedure('public.enroll_student_by_code(text)'))
		  ) > 0 as enrollment_identity_conflict_guard,
		  to_regprocedure('public.personal_campaign_id(text,text)') is not null as personal_campaign_id,
		  to_regprocedure('public.complete_solo_node(text,text,integer,smallint)') is not null as complete_solo_node,
		  to_regprocedure('public.award_player_cosmetics()') is not null as award_player_cosmetics,
		  to_regprocedure('public.equip_player_cosmetic(text)') is not null as equip_player_cosmetic
	`;
  const [mergedFeatureSchema] = await sql`
		select
		  exists (
		    select 1 from information_schema.columns
		    where table_schema = 'public' and table_name = 'battle_events'
	      and column_name = 'bot_difficulty'
		  ) as bot_difficulty,
		  exists (
		    select 1 from information_schema.columns
		    where table_schema = 'public' and table_name = 'school_settings'
	      and column_name = 'report_config'
		  ) as report_config,
		  exists (
		    select 1 from information_schema.columns
		    where table_schema = 'public' and table_name = 'assignments'
	      and column_name = 'instructions'
		  ) as assignment_instructions,
		  exists (
		    select 1 from information_schema.columns
		    where table_schema = 'public' and table_name = 'assignments'
	      and column_name = 'points'
		  ) as assignment_points
	`;
  const appliedMigrations = await sql`
		select name from public.battlegraf_schema_migrations
		where name in (
		  '20260913090000_bot_difficulty.sql',
		  '20260913091000_report_config.sql',
		  '20260913100000_assignment_instructions.sql',
		  '20260924010000_academic_traceability_hardening.sql',
		  '20260924020000_student_player_mode.sql',
		  '20260924030000_classes_rls_activation.sql',
		  '20260924040000_solo_progress_integrity.sql',
		  '20260924050000_student_onboarding_integrity.sql',
		  '20260924060000_canonical_class_enrollments.sql',
		  '20260924070000_enrollment_identity_consistency.sql',
		  '20260924080000_reject_conflicting_enrollment_identity.sql'
		)
		order by name
	`;
  const policyNames = new Set(
    scopedPolicies.map(({ policyname }) => policyname),
  );
  const rlsTables = new Set(rls.map(({ tablename }) => tablename));
  const [studentProfileIntegrity] = await sql`
		select
		  count(*) filter (where profile_count > 1)::int as memberships_with_multiple_profiles,
		  count(*) filter (where profile_count > 1 and section_profile_count = 1)::int as memberships_with_unique_sectioned_profile,
		  count(*) filter (where profile_count > 1 and section_profile_count <> 1)::int as memberships_still_ambiguous
		from (
		  select membership_id,
		    count(*)::int as profile_count,
		    count(*) filter (where section_id is not null)::int as section_profile_count
		  from public.student_profiles
		  where membership_id is not null
		  group by membership_id
		) profile_counts
	`;
  const [unlinkedRosterProfiles] = await sql`
		select count(*)::int as profiles_with_matching_membership
		from public.student_profiles sp
		where sp.membership_id is null
		  and coalesce(sp.is_demo, false) = false
		  and nullif(btrim(sp.email), '') is not null
		  and exists (
		    select 1
		    from public.memberships m
		    join auth.users u on u.id = m.user_id
		    where m.school_id = sp.school_id
		      and m.role = 'student'
		      and m.status = 'active'
		      and lower(btrim(sp.email)) = lower(btrim(coalesce(u.email, '')))
		  )
	`;
  const [onboardingSecurity] = await sql`
		select not has_function_privilege(
		  'authenticated',
		  'public.link_or_create_student_profile(uuid,uuid,text,text)',
		  'execute'
		) as roster_helper_is_private
	`;
  const securityChecks = {
    classesRlsEnabled: rlsTables.has("classes"),
    playerDataRlsEnabled: [
      "player_profiles",
      "solo_campaign_progress",
      "solo_campaign_node_catalog",
      "avatar_catalog",
      "player_cosmetics",
    ].every((table) => rlsTables.has(table)),
    unsafeSelfMembershipInsertRemoved: !policyNames.has(
      "user insert own membership join",
    ),
    broadStaffDirectoryReadRemoved: !policyNames.has("members read staff"),
    soloProgressOwnedReadPolicy: policyNames.has("solo_progress_read_own"),
    soloProgressWritePoliciesRemoved: ![...policyNames].some(
      (name) =>
        name === "solo_progress_insert_own" ||
        name === "solo_progress_update_own",
    ),
    rosterHelperIsPrivate: onboardingSecurity.roster_helper_is_private,
    allPlayerRpcFunctionsInstalled: Object.values(playerMode[0]).every(Boolean),
    mergedFeatureColumnsInstalled:
      Object.values(mergedFeatureSchema).every(Boolean),
    allRequiredMigrationsApplied: requiredMigrations.every((name) =>
      appliedMigrations.some((migration) => migration.name === name),
    ),
  };

  console.log(
    JSON.stringify(
      {
        tables: tables.map(({ table_name }) => table_name),
        rls: rls.map(({ tablename }) => tablename),
        plans,
        trials,
        seeded,
        playerMode: playerMode[0],
        mergedFeatureSchema,
        studentProfileIntegrity,
        unlinkedRosterProfiles,
        appliedMigrations,
        securityChecks,
      },
      null,
      2,
    ),
  );
  const failedChecks = Object.entries(securityChecks)
    .filter(([, passed]) => !passed)
    .map(([name]) => name);
  if (failedChecks.length > 0) {
    console.error(
      `Fallaron verificaciones de base de datos: ${failedChecks.join(", ")}`,
    );
    process.exitCode = 1;
  }
} finally {
  await sql.end({ timeout: 5 });
}
