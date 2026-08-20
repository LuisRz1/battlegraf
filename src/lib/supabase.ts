import { createServerClient, parseCookieHeader } from "@supabase/ssr";
import type { AstroCookies } from "astro";

function getSupabaseUrl() {
	// import.meta.env se resuelve en build time; process.env en runtime (Vercel SSR)
	return (
		import.meta.env.SUPABASE_URL ??
		import.meta.env.PUBLIC_SUPABASE_URL ??
		import.meta.env.NEXT_PUBLIC_SUPABASE_URL ??
		process.env.SUPABASE_URL ??
		process.env.PUBLIC_SUPABASE_URL ??
		process.env.NEXT_PUBLIC_SUPABASE_URL ??
		""
	);
}

function getSupabasePublishableKey() {
	return (
		import.meta.env.SUPABASE_PUBLISHABLE_KEY ??
		import.meta.env.PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
		import.meta.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
		import.meta.env.SUPABASE_ANON_KEY ??
		import.meta.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
		process.env.SUPABASE_PUBLISHABLE_KEY ??
		process.env.PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
		process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
		process.env.SUPABASE_ANON_KEY ??
		process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ??
		""
	);
}

export function hasSupabaseConfig() {
	return Boolean(getSupabaseUrl() && getSupabasePublishableKey());
}

export function createSupabaseServerClient({
	request,
	cookies,
}: {
	request: Request;
	cookies: AstroCookies;
}) {
	const url = getSupabaseUrl();
	const key = getSupabasePublishableKey();

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
