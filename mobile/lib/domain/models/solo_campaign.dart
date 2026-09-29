enum SoloNodeKind { lesson, choice, treasure, castle, boss }

class SoloQuizQuestion {
  const SoloQuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctOption,
  });

  final String prompt;
  final Map<String, String> options;
  final String correctOption;
}

class SoloRouteChoice {
  const SoloRouteChoice({
    required this.id,
    required this.title,
    required this.description,
    required this.colorKey,
  });

  final String id;
  final String title;
  final String description;
  final String colorKey;
}

class SoloCampaignNode {
  const SoloCampaignNode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
    required this.row,
    required this.lane,
    this.routeKey,
    this.questionIndex = 0,
    this.choices = const [],
  });

  final String id;
  final String title;
  final String subtitle;
  final SoloNodeKind kind;
  final int row;
  final int lane;
  final String? routeKey;
  final int questionIndex;
  final List<SoloRouteChoice> choices;
}

class SoloCampaignDefinition {
  SoloCampaignDefinition({required this.grade, required this.subject})
    : id = 'starter_${_slug(grade)}_${_slug(subject)}',
      nodes = _buildNodes(subject),
      questions = _questionPack(subject, grade);

  final String id;
  final String grade;
  final String subject;
  final List<SoloCampaignNode> nodes;
  final List<SoloQuizQuestion> questions;

  SoloCampaignNode node(String id) => nodes.firstWhere((node) => node.id == id);

  static List<SoloCampaignNode> _buildNodes(String subject) => [
    const SoloCampaignNode(
      id: 'first_step',
      title: 'Campamento',
      subtitle: 'Prepara tu primera expedición',
      kind: SoloNodeKind.lesson,
      row: 0,
      lane: 1,
      questionIndex: 0,
    ),
    const SoloCampaignNode(
      id: 'path_choice',
      title: 'El cruce',
      subtitle: 'Elige por dónde avanzar',
      kind: SoloNodeKind.choice,
      row: 1,
      lane: 1,
      choices: [
        SoloRouteChoice(
          id: 'forest',
          title: 'Sendero del bosque',
          description: 'Una ruta de descubrimientos y ciencia.',
          colorKey: 'forest',
        ),
        SoloRouteChoice(
          id: 'ruins',
          title: 'Ruinas antiguas',
          description: 'Una ruta de lógica, comunicación e historia.',
          colorKey: 'ruins',
        ),
      ],
    ),
    SoloCampaignNode(
      id: 'forest_lesson',
      title: 'Claro del bosque',
      subtitle: 'Resuelve un reto de $subject en el bosque',
      kind: SoloNodeKind.lesson,
      row: 2,
      lane: 0,
      routeKey: 'forest',
      questionIndex: 1,
    ),
    SoloCampaignNode(
      id: 'ruins_lesson',
      title: 'Sala de las ruinas',
      subtitle: 'Descifra una inscripción sobre $subject',
      kind: SoloNodeKind.lesson,
      row: 2,
      lane: 2,
      routeKey: 'ruins',
      questionIndex: 1,
    ),
    const SoloCampaignNode(
      id: 'forest_treasure',
      title: 'Cofre del guardián',
      subtitle: 'Una recompensa espera en el sendero',
      kind: SoloNodeKind.treasure,
      row: 3,
      lane: 0,
      routeKey: 'forest',
    ),
    const SoloCampaignNode(
      id: 'ruins_treasure',
      title: 'Cámara secreta',
      subtitle: 'Encuentra el sello de las ruinas',
      kind: SoloNodeKind.treasure,
      row: 3,
      lane: 2,
      routeKey: 'ruins',
    ),
    const SoloCampaignNode(
      id: 'castle_gate',
      title: 'Puerta del castillo',
      subtitle: 'Demuestra lo que aprendiste',
      kind: SoloNodeKind.castle,
      row: 4,
      lane: 1,
      questionIndex: 2,
    ),
    const SoloCampaignNode(
      id: 'castle_boss',
      title: 'Guardián del castillo',
      subtitle: 'Vence al rival para cerrar la expedición',
      kind: SoloNodeKind.boss,
      row: 5,
      lane: 1,
    ),
  ];

  static List<SoloQuizQuestion> _questionPack(String subject, String grade) {
    final key = _subjectKey(subject);
    final gradeNumber =
        int.tryParse(RegExp(r'\d+').firstMatch(grade)?.group(0) ?? '') ?? 5;
    if (grade.toLowerCase().contains('primaria') && gradeNumber <= 2) {
      return _earlyPrimaryPacks[key] ?? _earlyPrimaryPacks['general']!;
    }
    if (grade.toLowerCase().contains('secundaria')) {
      return _secondaryPacks[key] ?? _secondaryPacks['general']!;
    }
    return _packs[key] ?? _packs['general']!;
  }

  static String _subjectKey(String subject) {
    final value = subject.toLowerCase();
    if (value.contains('mat') || value.contains('math')) return 'math';
    if (value.contains('comun') ||
        value.contains('leng') ||
        value.contains('language')) {
      return 'language';
    }
    if (value.contains('cien') || value.contains('science')) return 'science';
    if (value.contains('hist')) return 'history';
    return 'general';
  }

  static String _slug(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  static const Map<String, List<SoloQuizQuestion>> _packs = {
    'math': [
      SoloQuizQuestion(
        prompt:
            'Si 3/4 de una ruta están recorridos y falta 1/4, ¿qué fracción representa el camino completo?',
        options: {'A': '1/2', 'B': '1', 'C': '4/8', 'D': '2'},
        correctOption: 'B',
      ),
      SoloQuizQuestion(
        prompt:
            'Un mapa tiene 5 caminos por zona y recorres 7 zonas. ¿Cuántos caminos revisaste?',
        options: {'A': '12', 'B': '30', 'C': '35', 'D': '57'},
        correctOption: 'C',
      ),
      SoloQuizQuestion(
        prompt:
            'El castillo está en el punto (6, 4). ¿Cuál es el área del rectángulo que cubre el mapa?',
        options: {'A': '10', 'B': '20', 'C': '24', 'D': '28'},
        correctOption: 'C',
      ),
    ],
    'language': [
      SoloQuizQuestion(
        prompt: '¿Qué ayuda a entender la idea principal de una historia?',
        options: {
          'A': 'Buscar el mensaje que conecta sus partes',
          'B': 'Leer solo la última palabra',
          'C': 'Ignorar los personajes',
          'D': 'Contar las letras del título',
        },
        correctOption: 'A',
      ),
      SoloQuizQuestion(
        prompt: '¿Cuál oración usa correctamente la coma?',
        options: {
          'A': 'Ana compró, pan leche y fruta.',
          'B': 'Ana, compró pan leche y fruta.',
          'C': 'Ana compró pan, leche y fruta.',
          'D': 'Ana compró pan leche, y fruta.',
        },
        correctOption: 'C',
      ),
      SoloQuizQuestion(
        prompt:
            '¿Qué palabra conecta mejor estas ideas: estudió mucho, ___ aprobó el reto?',
        options: {
          'A': 'aunque',
          'B': 'por eso',
          'C': 'mientras',
          'D': 'pero no',
        },
        correctOption: 'B',
      ),
    ],
    'science': [
      SoloQuizQuestion(
        prompt: '¿Qué órgano bombea la sangre por el cuerpo?',
        options: {
          'A': 'El corazón',
          'B': 'El estómago',
          'C': 'El pulmón',
          'D': 'El riñón',
        },
        correctOption: 'A',
      ),
      SoloQuizQuestion(
        prompt: '¿Cuál es un cambio físico de la materia?',
        options: {
          'A': 'Quemar papel',
          'B': 'Oxidar hierro',
          'C': 'Derretir hielo',
          'D': 'Cocinar un huevo',
        },
        correctOption: 'C',
      ),
      SoloQuizQuestion(
        prompt:
            '¿Qué proceso permite a las plantas producir alimento usando luz?',
        options: {
          'A': 'Evaporación',
          'B': 'Fotosíntesis',
          'C': 'Condensación',
          'D': 'Erosión',
        },
        correctOption: 'B',
      ),
    ],
    'history': [
      SoloQuizQuestion(
        prompt: '¿Qué fuente ayuda a investigar hechos del pasado?',
        options: {
          'A': 'Solo rumores',
          'B': 'Documentos, objetos y testimonios',
          'C': 'Únicamente predicciones',
          'D': 'Ninguna evidencia',
        },
        correctOption: 'B',
      ),
      SoloQuizQuestion(
        prompt: '¿Para qué sirve una línea de tiempo?',
        options: {
          'A': 'Ordenar acontecimientos cronológicamente',
          'B': 'Medir la temperatura',
          'C': 'Resolver una ecuación',
          'D': 'Clasificar seres vivos',
        },
        correctOption: 'A',
      ),
      SoloQuizQuestion(
        prompt: '¿Qué permite comparar dos fuentes históricas?',
        options: {
          'A': 'Revisar autor, fecha y contexto',
          'B': 'Escoger la más larga sin leer',
          'C': 'Ignorar cuándo se escribió',
          'D': 'Usar solo una opinión',
        },
        correctOption: 'A',
      ),
    ],
    'general': [
      SoloQuizQuestion(
        prompt: '¿Qué estrategia favorece un aprendizaje duradero?',
        options: {
          'A': 'Repasar con pausas y explicar lo aprendido',
          'B': 'Memorizar sin comprender una sola vez',
          'C': 'Evitar toda retroalimentación',
          'D': 'Estudiar únicamente después del examen',
        },
        correctOption: 'A',
      ),
      SoloQuizQuestion(
        prompt:
            'Si encuentras dos caminos posibles, ¿qué decisión es más útil?',
        options: {
          'A': 'Comparar pistas y elegir conscientemente',
          'B': 'Cerrar el mapa',
          'C': 'Elegir siempre al azar',
          'D': 'Ignorar la meta',
        },
        correctOption: 'A',
      ),
      SoloQuizQuestion(
        prompt: '¿Qué haces después de equivocarte en un reto?',
        options: {
          'A': 'Revisar la explicación y volver a intentar',
          'B': 'Borrar lo que aprendiste',
          'C': 'Dejar de hacer preguntas',
          'D': 'Escoger sin pensar',
        },
        correctOption: 'A',
      ),
    ],
  };

  static final Map<String, List<SoloQuizQuestion>> _earlyPrimaryPacks = {
    'math': [
      const SoloQuizQuestion(
        prompt:
            'En el sendero hay 3 banderas rojas y 2 moradas. ¿Cuántas hay en total?',
        options: {'A': '4', 'B': '5', 'C': '6', 'D': '7'},
        correctOption: 'B',
      ),
      const SoloQuizQuestion(
        prompt: 'El cofre tiene 8 monedas y regalas 3. ¿Cuántas quedan?',
        options: {'A': '4', 'B': '5', 'C': '6', 'D': '11'},
        correctOption: 'B',
      ),
      const SoloQuizQuestion(
        prompt: '¿Qué número viene después de 14 en la ruta?',
        options: {'A': '13', 'B': '15', 'C': '16', 'D': '24'},
        correctOption: 'B',
      ),
    ],
    'language': [
      const SoloQuizQuestion(
        prompt: '¿Cuál es una oración completa?',
        options: {
          'A': 'El castillo grande',
          'B': 'La niña encontró una pista.',
          'C': 'Debajo del puente',
          'D': 'Muy rápido',
        },
        correctOption: 'B',
      ),
      const SoloQuizQuestion(
        prompt: '¿Qué palabra significa lo contrario de “oscuro”?',
        options: {'A': 'Claro', 'B': 'Lento', 'C': 'Lejos', 'D': 'Fuerte'},
        correctOption: 'A',
      ),
      const SoloQuizQuestion(
        prompt: '¿Qué signo va al final de una pregunta?',
        options: {'A': '.', 'B': ',', 'C': '?', 'D': '!'},
        correctOption: 'C',
      ),
    ],
    'science': [
      const SoloQuizQuestion(
        prompt: '¿Qué necesitan muchas plantas para crecer?',
        options: {
          'A': 'Luz y agua',
          'B': 'Humo',
          'C': 'Plástico',
          'D': 'Oscuridad total',
        },
        correctOption: 'A',
      ),
      const SoloQuizQuestion(
        prompt: '¿Cuál de estos animales nace de un huevo?',
        options: {'A': 'Gallina', 'B': 'Perro', 'C': 'Gato', 'D': 'Caballo'},
        correctOption: 'A',
      ),
      const SoloQuizQuestion(
        prompt: '¿Qué parte del cuerpo usamos para escuchar?',
        options: {'A': 'Ojos', 'B': 'Oídos', 'C': 'Manos', 'D': 'Rodillas'},
        correctOption: 'B',
      ),
    ],
    'history': [
      const SoloQuizQuestion(
        prompt: '¿Qué objeto puede mostrar cómo vestían antes las personas?',
        options: {
          'A': 'Una fotografía antigua',
          'B': 'Un pronóstico',
          'C': 'Un videojuego nuevo',
          'D': 'Una nube',
        },
        correctOption: 'A',
      ),
      const SoloQuizQuestion(
        prompt: '¿Qué ayuda a ordenar hechos de antes y después?',
        options: {
          'A': 'Línea de tiempo',
          'B': 'Mapa del clima',
          'C': 'Regla de medir',
          'D': 'Termómetro',
        },
        correctOption: 'A',
      ),
      const SoloQuizQuestion(
        prompt: '¿Cuál es un lugar donde podemos cuidar objetos antiguos?',
        options: {
          'A': 'Museo',
          'B': 'Piscina',
          'C': 'Cancha',
          'D': 'Tienda de frutas',
        },
        correctOption: 'A',
      ),
    ],
    'general': _packs['general']!,
  };

  static final Map<String, List<SoloQuizQuestion>> _secondaryPacks = {
    'math': [
      const SoloQuizQuestion(
        prompt: 'Si 5x = 35, ¿cuánto vale x?',
        options: {'A': '5', 'B': '6', 'C': '7', 'D': '8'},
        correctOption: 'C',
      ),
      const SoloQuizQuestion(
        prompt:
            'Una ruta de 12 km se divide en 3 tramos iguales. ¿Cuánto mide cada tramo?',
        options: {'A': '3 km', 'B': '4 km', 'C': '6 km', 'D': '9 km'},
        correctOption: 'B',
      ),
      const SoloQuizQuestion(
        prompt: '¿Cuál es el área de un rectángulo de 6 por 4 unidades?',
        options: {'A': '10', 'B': '20', 'C': '24', 'D': '28'},
        correctOption: 'C',
      ),
    ],
    'language': [
      const SoloQuizQuestion(
        prompt: '¿Qué recurso permite inferir la intención del narrador?',
        options: {
          'A': 'Relacionar tono, hechos y punto de vista',
          'B': 'Contar los párrafos',
          'C': 'Leer solo el título',
          'D': 'Buscar una palabra al azar',
        },
        correctOption: 'A',
      ),
      const SoloQuizQuestion(
        prompt: '¿Cuál opción presenta una conclusión apoyada en evidencia?',
        options: {
          'A': 'Es verdad porque lo digo',
          'B': 'Los datos muestran una tendencia repetida',
          'C': 'Todos piensan igual',
          'D': 'No hace falta revisar fuentes',
        },
        correctOption: 'B',
      ),
      ..._packs['language']!.take(1),
    ],
    'science': [
      const SoloQuizQuestion(
        prompt: '¿Qué ley relaciona fuerza, masa y aceleración?',
        options: {
          'A': 'Primera ley de Newton',
          'B': 'Segunda ley de Newton',
          'C': 'Ley de reflexión',
          'D': 'Ley de conservación de masa',
        },
        correctOption: 'B',
      ),
      const SoloQuizQuestion(
        prompt:
            'En un ecosistema, ¿qué puede ocurrir si desaparece un depredador clave?',
        options: {
          'A': 'Se modifica el equilibrio de poblaciones',
          'B': 'No cambia ninguna población',
          'C': 'Desaparece la energía solar',
          'D': 'Se detiene el ciclo del agua',
        },
        correctOption: 'A',
      ),
      ..._packs['science']!.take(1),
    ],
    'history': [
      const SoloQuizQuestion(
        prompt: '¿Por qué se contrastan fuentes históricas?',
        options: {
          'A': 'Para reconocer perspectivas y comprobar evidencias',
          'B': 'Para usar solo la fuente más reciente',
          'C': 'Para evitar contexto',
          'D': 'Para eliminar testimonios',
        },
        correctOption: 'A',
      ),
      const SoloQuizQuestion(
        prompt: '¿Qué distingue un análisis histórico de una opinión?',
        options: {
          'A': 'La relación entre fuentes, contexto y argumento',
          'B': 'La extensión del texto',
          'C': 'El uso de una fecha solamente',
          'D': 'La cantidad de adjetivos',
        },
        correctOption: 'A',
      ),
      ..._packs['history']!.take(1),
    ],
    'general': _packs['general']!,
  };
}
