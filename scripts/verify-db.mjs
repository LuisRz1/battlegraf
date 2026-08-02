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
			'subscriptions', 'student_profiles'
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
			'subscriptions', 'student_profiles'
		  )
		order by tablename
	`;

	console.log(JSON.stringify({
		tables: tables.map(({ table_name }) => table_name),
		rls: rls.map(({ tablename }) => tablename),
		plans,
	}, null, 2));
} finally {
	await sql.end({ timeout: 5 });
}
