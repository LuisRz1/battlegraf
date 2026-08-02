import type { APIRoute } from "astro";
import { createSupabaseServerClient, hasSupabaseConfig } from "../../lib/supabase";

const csvCell = (value: unknown) => `"${String(value ?? "").replaceAll('"', '""')}"`;

export const GET: APIRoute = async ({ request, cookies, redirect }) => {
	if (!hasSupabaseConfig()) return new Response("Servicio no configurado", { status: 503 });
	const supabase = createSupabaseServerClient({ request, cookies });
	const { data: userData } = await supabase.auth.getUser();
	if (!userData.user) return redirect("/iniciar-sesion", 303);
	const { data: membership } = await supabase.from("memberships").select("school_id").eq("user_id", userData.user.id).limit(1).maybeSingle();
	if (!membership) return new Response("Sin permisos", { status: 403 });
	const { data: logs } = await supabase.from("audit_logs").select("created_at, actor_name, action, target_label, category").eq("school_id", membership.school_id).order("created_at", { ascending: false }).limit(1000);
	const rows = [["Fecha", "Actor", "Accion", "Objetivo", "Categoria"], ...(logs ?? []).map((log) => [log.created_at, log.actor_name, log.action, log.target_label, log.category])];
	const body = "\uFEFF" + rows.map((row) => row.map(csvCell).join(",")).join("\r\n");
	return new Response(body, { headers: { "content-type": "text/csv; charset=utf-8", "content-disposition": 'attachment; filename="battlegraf-auditoria.csv"' } });
};
