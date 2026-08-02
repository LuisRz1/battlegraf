import postgres from "postgres";

const connectionString =
	process.env.POSTGRES_URL_NON_POOLING ?? process.env.POSTGRES_URL;

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
			'learning_materials', 'question_bank', 'school_settings'
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
			'learning_materials', 'question_bank', 'school_settings'
		  )
		order by tablename
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

	console.log(JSON.stringify({
		tables: tables.map(({ table_name }) => table_name),
		rls: rls.map(({ tablename }) => tablename),
		plans,
		trials,
		seeded,
	}, null, 2));
} finally {
	await sql.end({ timeout: 5 });
}
