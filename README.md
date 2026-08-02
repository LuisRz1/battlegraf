# BattleGraph — landing y acceso institucional

Landing retro medieval, demo web y flujo de adquisición institucional de BattleGraph.

## Rutas

- `/` — presentación del juego, demo y resumen de planes.
- `/planes` — comparación de los cuatro niveles de suscripción.
- `/registro?plan=explorador` — registro institucional con Google.
- `/panel` — onboarding y estado de la cuenta autenticada.
- `/auth/google` y `/auth/callback` — OAuth con PKCE.

## Desarrollo local

El repositorio usa Bun.

```sh
bun install
copy .env.example .env
bun run dev
```

Comprobaciones:

```sh
bun run astro check
bun run build
```

## Supabase

1. Cree un proyecto en Supabase.
2. Ejecute `bun run db:migrate` con `POSTGRES_URL_NON_POOLING` disponible.
3. Habilite Google en Authentication → Providers.
4. Añada `http://localhost:4321/auth/callback` y la URL productiva a las redirecciones autorizadas.
5. Configure las variables descritas en `.env.example` tanto en local como en Vercel.

Las sesiones viven en cookies SSR. PostgreSQL conserva perfiles, colegios, membresías y suscripciones; las políticas RLS aíslan los datos por institución. La integración de Vercel Marketplace proporciona automáticamente `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` y las conexiones PostgreSQL.

El alta institucional genera una configuración demostrativa editable con secciones, materias, clanes, alumnos, materiales, preguntas y reglas por turnos. El plan Explorador recibe siete días con las capacidades de Red Educativa y luego continúa con sus límites gratuitos. Las cuentas existentes acceden desde `/iniciar-sesion` sin duplicar el colegio ni reiniciar la prueba.

## Despliegue

El proyecto usa `@astrojs/vercel` y `output: "server"` para servir rutas autenticadas. Conecte este repositorio a Vercel, copie las variables de entorno y despliegue después de ejecutar la migración.

El export de Godot se encuentra en `public/game/` y no debe editarse manualmente.
