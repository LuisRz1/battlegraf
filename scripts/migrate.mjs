import { readFile, readdir } from "node:fs/promises";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import postgres from "postgres";

const connectionString =
	process.env.POSTGRES_URL_NON_POOLING ?? process.env.POSTGRES_URL;

if (!connectionString) {
	throw new Error("Falta POSTGRES_URL_NON_POOLING o POSTGRES_URL.");
}

const migrationsDirectory = fileURLToPath(
	new URL("../supabase/migrations/", import.meta.url),
);
const sql = postgres(connectionString, {
	max: 1,
	ssl: "require",
	connect_timeout: 20,
});

try {
	await sql`create table if not exists public.battlegraf_schema_migrations (
		name text primary key,
		applied_at timestamptz not null default now()
	)`;

	const files = (await readdir(migrationsDirectory))
		.filter((file) => file.endsWith(".sql"))
		.sort();
	const [{ count: migrationCount }] = await sql`
		select count(*)::int as count from public.battlegraf_schema_migrations
	`;

	if (migrationCount === 0) {
		const [{ exists: hasInitialSchema }] = await sql`
			select to_regclass('public.plans') is not null as exists
		`;
		if (hasInitialSchema && files[0]) {
			await sql`
				insert into public.battlegraf_schema_migrations (name)
				values (${files[0]}) on conflict do nothing
			`;
		}
	}

	for (const file of files) {
		const [alreadyApplied] = await sql`
			select 1 from public.battlegraf_schema_migrations where name = ${file}
		`;
		if (alreadyApplied) continue;

		const migration = await readFile(join(migrationsDirectory, file), "utf8");
		await sql.begin(async (transaction) => {
			await transaction.unsafe(migration);
			await transaction`
				insert into public.battlegraf_schema_migrations (name) values (${file})
			`;
		});
		console.log(`Aplicada: ${file}`);
	}

	console.log("Migraciones BattleGraph al dia.");
} finally {
	await sql.end({ timeout: 5 });
}
