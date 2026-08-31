import type { APIRoute } from "astro";
import { createSupabaseServerClient } from "../../lib/supabase";

export const prerender = false;
const API_BASE = process.env.PANEL_API_URL ?? "https://battlegraf-production.up.railway.app";

export const GET: APIRoute = async ({ request, cookies, url }) => {
	try {
		const supabase = createSupabaseServerClient({ request, cookies });
		const { data: sessionData } = await supabase.auth.getSession();
		const apiToken = sessionData?.session?.access_token ?? "";
		const studentId = url.searchParams.get("student_id") ?? "";
		const schoolId = url.searchParams.get("school_id") ?? "";
		if (!apiToken) return new Response(JSON.stringify({ ok: false, detail: "Sin sesión" }), { status: 401 });
		if (!studentId || !schoolId) return new Response(JSON.stringify({ ok: false, detail: "Faltan parámetros" }), { status: 400 });
		const r = await fetch(`${API_BASE}/api/v1/panel/${schoolId}/students/${studentId}/tracking`, {
			headers: { Authorization: `Bearer ${apiToken}` },
		});
		if (!r.ok) return new Response(JSON.stringify({ ok: false, detail: `backend ${r.status}` }), { status: 502 });
		const body = await r.json();
		return new Response(JSON.stringify({ ok: true, tracking: body }), { status: 200, headers: { "Content-Type": "application/json" } });
	} catch (e) {
		console.error("seguimiento error", e);
		return new Response(JSON.stringify({ ok: false, detail: "api_down" }), { status: 502 });
	}
};