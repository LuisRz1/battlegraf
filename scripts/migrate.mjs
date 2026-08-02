import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import postgres from "postgres";

const connectionString =
	process.env.POSTGRES_URL_NON_POOLING ?? process.env.POSTGRES_URL;

if (!connectionString) {
	throw new Error("Falta POSTGRES_URL_NON_POOLING o POSTGRES_URL.");
}

const migrationUrl = new URL(
	"../supabase/migrations/20260802010000_battlegraf_accounts.sql",
	import.meta.url,
);
const migration = await readFile(fileURLToPath(migrationUrl), "utf8");
const sql = postgres(connectionString, {
	max: 1,
	ssl: "require",
	connect_timeout: 20,
});

try {
	await sql.begin(async (transaction) => {
		await transaction.unsafe(migration);
	});
	console.log("Migración BattleGraph aplicada correctamente.");
} finally {
	await sql.end({ timeout: 5 });
}
