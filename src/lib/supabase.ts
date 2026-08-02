import { createServerClient, parseCookieHeader } from "@supabase/ssr";
import type { AstroCookies } from "astro";

export function hasSupabaseConfig() {
	return Boolean(
		import.meta.env.PUBLIC_SUPABASE_URL &&
			import.meta.env.PUBLIC_SUPABASE_PUBLISHABLE_KEY,
	);
}

export function createSupabaseServerClient({
	request,
	cookies,
}: {
	request: Request;
	cookies: AstroCookies;
}) {
	const url = import.meta.env.PUBLIC_SUPABASE_URL;
	const key = import.meta.env.PUBLIC_SUPABASE_PUBLISHABLE_KEY;

	if (!url || !key) {
		throw new Error("Supabase no está configurado. Revise las variables de entorno.");
	}

	return createServerClient(url, key, {
		cookies: {
			getAll() {
				return parseCookieHeader(request.headers.get("Cookie") ?? "");
			},
			setAll(cookiesToSet) {
				cookiesToSet.forEach(({ name, value, options }) => {
					cookies.set(name, value, options);
				});
			},
		},
	});
}

export function getPublicOrigin(request: Request) {
	const configured = import.meta.env.PUBLIC_SITE_URL?.replace(/\/$/, "");
	if (configured) return configured;

	const requestUrl = new URL(request.url);
	const forwardedHost = request.headers.get("x-forwarded-host");
	const forwardedProto = request.headers.get("x-forwarded-proto") ?? "https";
	return forwardedHost
		? `${forwardedProto}://${forwardedHost}`
		: requestUrl.origin;
}
