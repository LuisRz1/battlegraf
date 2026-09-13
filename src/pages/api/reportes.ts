import type { APIRoute } from "astro";
import {
	createSupabaseServerClient,
	hasSupabaseConfig,
} from "../../lib/supabase";

const API_BASE =
	process.env.PANEL_API_URL ?? "https://battlegraf-production.up.railway.app";

async function session(request: Request, cookies: any) {
	const supabase = createSupabaseServerClient({ request, cookies });
	const { data: userData } = await supabase.auth.getUser();
	if (!userData.user) return null;
	const { data: membership } = await supabase
		.from("memberships")
		.select("school_id")
		.eq("user_id", userData.user.id)
		.order("created_at")
		.limit(1)
		.maybeSingle();
	if (!membership?.school_id) return null;
	const { data: sessionData } = await supabase.auth.getSession();
	const token = sessionData?.session?.access_token ?? "";
	if (!token) return null;
	return { schoolId: membership.school_id as string, token };
}

export const GET: APIRoute = async ({ request, cookies, url }) => {
	if (!hasSupabaseConfig())
		return new Response("Servicio no configurado", { status: 503 });
	const auth = await session(request, cookies);
	if (!auth) return new Response("Sin sesión", { status: 401 });
	const { schoolId, token } = auth;

	const type = url.searchParams.get("type") ?? "overview";
	const format = url.searchParams.get("format") ?? "json";
	const section = url.searchParams.get("section") ?? "";
	const student = url.searchParams.get("student") ?? "";

	let path = "/reports/overview";
	if (type === "staff") path = "/reports/staff";
	else if (type === "student" && student)
		path = `/reports/student/${encodeURIComponent(student)}`;
	else if (type === "class" && section)
		path = `/reports/class/${encodeURIComponent(section)}`;
	else if (type === "overview") path = "/reports/overview";
	if (format === "csv") {
		if (type === "staff") path = "/reports/staff?export=true";
		else if (type === "class")
			path = `/reports/class/${encodeURIComponent(section)}?export=true`;
		else if (type === "overview") path = "/reports/overview?export=true";
		else return new Response("Tipo de export no soportado", { status: 400 });
	}

	try {
		const res = await fetch(`${API_BASE}/api/v1/panel/${schoolId}${path}`, {
			headers: { Authorization: `Bearer ${token}` },
		});
		if (!res.ok) {
			return new Response("No se pudo generar el reporte", { status: 502 });
		}
		const body = await res.text();
		if (format === "csv") {
			return new Response(body, {
				headers: {
					"content-type": "text/csv; charset=utf-8",
					"content-disposition": `attachment; filename="battlegraf-${type}.csv"`,
				},
			});
		}
		return new Response(body, {
			headers: {
				"content-type": "application/json; charset=utf-8",
				"cache-control": "no-store",
			},
		});
	} catch (error) {
		console.error("reportes error", error);
		return new Response("No se pudo generar el reporte", { status: 502 });
	}
};

export const POST: APIRoute = async ({ request, cookies }) => {
	if (!hasSupabaseConfig())
		return new Response("Servicio no configurado", { status: 503 });
	const auth = await session(request, cookies);
	if (!auth) return new Response("Sin sesión", { status: 401 });
	const { schoolId, token } = auth;
	const form = await request.formData();
	const goal = Number(form.get("goal") ?? 80);
	const weights = {
		grades: Number(form.get("weight_grades") ?? 40),
		attendance: Number(form.get("weight_attendance") ?? 20),
		tasks: Number(form.get("weight_tasks") ?? 20),
		practice: Number(form.get("weight_practice") ?? 20),
	};
	try {
		const res = await fetch(
			`${API_BASE}/api/v1/panel/${schoolId}/reports/config`,
			{
				method: "POST",
				headers: {
					Authorization: `Bearer ${token}`,
					"Content-Type": "application/json",
				},
				body: JSON.stringify({ goal, weights }),
			},
		);
		return new Response(null, {
			status: 303,
			headers: {
				location: res.ok
					? "/panel?view=reportes&saved=change"
					: "/panel?view=reportes&error=save",
			},
		});
	} catch (error) {
		console.error("reportes config error", error);
		return new Response(null, {
			status: 303,
			headers: { location: "/panel?view=reportes&error=save" },
		});
	}
};
