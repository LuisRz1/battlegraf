import type { APIRoute } from "astro";
import {
	createSupabaseServerClient,
	hasSupabaseConfig,
} from "../../lib/supabase";

const API_BASE =
	process.env.PANEL_API_URL ?? "https://battlegraf-production.up.railway.app";

export const GET: APIRoute = async ({ request, cookies, url }) => {
	if (!hasSupabaseConfig())
		return new Response("Servicio no configurado", { status: 503 });
	const supabase = createSupabaseServerClient({ request, cookies });
	const { data: userData } = await supabase.auth.getUser();
	if (!userData.user) return new Response("Sin sesión", { status: 401 });
	const { data: membership } = await supabase
		.from("memberships")
		.select("school_id")
		.eq("user_id", userData.user.id)
		.limit(1)
		.maybeSingle();
	const schoolId = membership?.school_id;
	if (!schoolId) return new Response("Sin institución", { status: 403 });
	const { data: sessionData } = await supabase.auth.getSession();
	const token = sessionData?.session?.access_token ?? "";
	if (!token) return new Response("Sin sesión", { status: 401 });

	const type = url.searchParams.get("type") ?? "class";
	const section = url.searchParams.get("section") ?? "";
	const path =
		type === "staff"
			? "/reports/staff?export=true"
			: `/reports/class/${encodeURIComponent(section)}?export=true`;

	try {
		const res = await fetch(`${API_BASE}/api/v1/panel/${schoolId}${path}`, {
			headers: { Authorization: `Bearer ${token}` },
		});
		if (!res.ok) {
			return new Response("No se pudo generar el reporte", { status: 502 });
		}
		const body = await res.text();
		return new Response(body, {
			headers: {
				"content-type": "text/csv; charset=utf-8",
				"content-disposition": `attachment; filename="battlegraf-${type}.csv"`,
			},
		});
	} catch (error) {
		console.error("reportes error", error);
		return new Response("No se pudo generar el reporte", { status: 502 });
	}
};
