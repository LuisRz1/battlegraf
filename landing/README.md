# BattleGraf Landing

Landing pública e interactiva de BattleGraf, una plataforma escolar que
transforma materiales, preguntas y tareas en batallas estratégicas sobre
grafos.

## Incluye

- Presentación del proyecto y su propuesta educativa.
- Explicación del ciclo colegio, docente y estudiante.
- Reglas principales de las batallas por turnos.
- Vista responsive para escritorio y dispositivos móviles.
- Prototipo jugable integrado con rutas, preguntas y conquista de nodos.
- Estética retro arcade en rojo y morado, sin emojis.

## Desarrollo

Requiere Node.js 22.

```bash
npm install
npm run dev
```

## Validación

```bash
npm run build
npm test
npx next build
```

`npm run build` genera la versión compatible con Sites. Vercel utiliza
`npx next build` mediante `vercel.json`.

## Producción

- Vercel: https://battlegraf-landing.vercel.app
