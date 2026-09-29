import type { APIRoute } from "astro";
import {
	createSupabaseServerClient,
	hasSupabaseConfig,
} from "../../lib/supabase";

const API_BASE =
	process.env.PANEL_API_URL ?? "https://battlegraf-production.up.railway.app";

export const POST: APIRoute = async ({ request, cookies, redirect }) => {
	if (!hasSupabaseConfig())
		return new Response("Servicio no configurado", { status: 503 });
	const supabase = createSupabaseServerClient({ request, cookies });
	const { data: userData } = await supabase.auth.getUser();
	if (!userData.user) return redirect("/iniciar-sesion", 303);
	const { data: sessionData } = await supabase.auth.getSession();
	const token = sessionData?.session?.access_token ?? "";
	if (!token) return new Response("Sin sesión", { status: 401 });

	const form = await request.formData();
	const schoolId = String(form.get("school_id") ?? "").slice(0, 40);
	const prompt = String(form.get("prompt") ?? "")
		.trim()
		.slice(0, 2000);
	const safeViews = [
		"centro",
		"perfil",
		"colegio",
		"clases",
		"secciones",
		"materias",
		"personas",
		"academico",
		"materiales",
		"preguntas",
		"tareas",
		"batallas",
		"progreso",
		"recompensas",
		"misiones",
		"metas",
		"reportes",
		"asistente",
		"auditoria",
	];
	const requestedView = String(form.get("redirect") ?? "asistente");
	const backView = safeViews.includes(requestedView)
		? requestedView
		: "asistente";
	if (!schoolId || prompt.length < 1)
		return redirect(`/panel?view=${backView}&error=validation`, 303);

	try {
		const res = await fetch(
			`${API_BASE}/api/v1/panel/${schoolId}/me/assistant`,
			{
				method: "POST",
				headers: {
					Authorization: `Bearer ${token}`,
					"Content-Type": "application/json",
				},
				body: JSON.stringify({ prompt }),
			},
		);
		return redirect(
			res.ok
				? `/panel?view=${backView}&saved=assistant`
				: `/panel?view=${backView}&error=save`,
			303,
		);
	} catch (error) {
		console.error("asistente error", error);
		return redirect(`/panel?view=${backView}&error=save`, 303);
	}
};
