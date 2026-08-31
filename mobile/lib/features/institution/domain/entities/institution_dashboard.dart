typedef JsonMap = Map<String, dynamic>;

/// Snapshot institucional independiente de Flutter, Dio y Supabase.
///
/// El backend ya entrega colecciones heterogéneas para el panel web. Se
/// conservan como mapas inmutables en el dominio para que la app móvil pueda
/// evolucionar al mismo ritmo sin acoplar widgets al transporte HTTP.
class InstitutionDashboard {
  const InstitutionDashboard({
    required this.schoolId,
    required this.viewerRole,
    required this.school,
    required this.subscription,
    required this.settings,
    required this.students,
    required this.sections,
    required this.subjects,
    required this.subjectTeachers,
    required this.staff,
    required this.classes,
    required this.enrollments,
    required this.materials,
    required this.questions,
    required this.assignments,
    required this.battles,
    required this.ranks,
    required this.clans,
    required this.audits,
  });

  final String schoolId;
  final String viewerRole;
  final JsonMap school;
  final JsonMap subscription;
  final JsonMap settings;
  final List<JsonMap> students;
  final List<JsonMap> sections;
  final List<JsonMap> subjects;
  final List<JsonMap> subjectTeachers;
  final List<JsonMap> staff;
  final List<JsonMap> classes;
  final List<JsonMap> enrollments;
  final List<JsonMap> materials;
  final List<JsonMap> questions;
  final List<JsonMap> assignments;
  final List<JsonMap> battles;
  final List<JsonMap> ranks;
  final List<JsonMap> clans;
  final List<JsonMap> audits;

  factory InstitutionDashboard.fromJson(JsonMap json) {
    List<JsonMap> rows(String key) => List<JsonMap>.from(
      (json[key] as List? ?? const []).map(
        (item) => JsonMap.unmodifiable(JsonMap.from(item as Map)),
      ),
    );

    return InstitutionDashboard(
      schoolId: '${json['school_id'] ?? ''}',
      viewerRole: '${json['viewer_role'] ?? ''}',
      school: JsonMap.unmodifiable(
        JsonMap.from(json['school'] as Map? ?? const {}),
      ),
      subscription: JsonMap.unmodifiable(
        JsonMap.from(json['subscription'] as Map? ?? const {}),
      ),
      settings: JsonMap.unmodifiable(
        JsonMap.from(json['settings'] as Map? ?? const {}),
      ),
      students: rows('students'),
      sections: rows('sections'),
      subjects: rows('subjects'),
      subjectTeachers: rows('subject_teachers'),
      staff: rows('staff'),
      classes: rows('classes'),
      enrollments: rows('enrollments'),
      materials: rows('materials'),
      questions: rows('questions'),
      assignments: rows('assignments'),
      battles: rows('battles'),
      ranks: rows('ranks'),
      clans: rows('clans'),
      audits: rows('audits'),
    );
  }
}

class AcademicOverview {
  const AcademicOverview(this.data);

  final JsonMap data;

  JsonMap get metrics => JsonMap.from(data['metrics'] as Map? ?? const {});
  List<JsonMap> get students => _rows('students');
  List<JsonMap> get subjects => _rows('subjects');
  List<JsonMap> get sections => _rows('sections');
  List<JsonMap> get periods => _rows('periods');
  List<JsonMap> get gradeItems => _rows('grade_items');
  List<JsonMap> get subjectPerformance => _rows('subject_performance');

  List<JsonMap> _rows(String key) => List<JsonMap>.from(
    (data[key] as List? ?? const []).map((item) => JsonMap.from(item as Map)),
  );
}
