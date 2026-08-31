# Arquitectura móvil

La aplicación se implementa con Flutter y Riverpod. El módulo institucional usa
Clean Architecture con puertos y adaptadores (arquitectura hexagonal), igual que
la separación de responsabilidades del sistema web y backend.

```text
lib/features/institution/
├── domain/
│   ├── entities/                 modelos independientes de Flutter y HTTP
│   └── repositories/             puertos que define el dominio
├── application/
│   └── use_cases/                casos de uso de la aplicación
├── infrastructure/
│   ├── data_sources/             adaptador HTTP hacia Railway
│   └── repositories/             implementación de los puertos
└── presentation/
    ├── providers/                estado Riverpod e inyección
    └── views/                    interfaz adaptable por rol
```

Reglas de dependencia:

1. `domain` no importa Flutter, Dio, Supabase ni Riverpod.
2. `application` depende únicamente de puertos del dominio.
3. `infrastructure` implementa esos puertos y encapsula Dio.
4. `presentation` ejecuta casos de uso o puertos mediante providers; los widgets
   no construyen peticiones HTTP.
5. Supabase autentica; el token de sesión se inyecta al adaptador de Railway.
6. El backend vuelve a comprobar rol, institución y alcance de alumnos.

Las rutas de producción exponen el módulo institucional y el prototipo jugable
offline. Las pantallas antiguas que dependían de los endpoints JWT iniciales ya
no forman parte del enrutamiento activo.
