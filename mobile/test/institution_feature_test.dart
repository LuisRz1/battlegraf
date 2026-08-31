import 'package:flutter_test/flutter_test.dart';

import 'package:battlegraf_mobile/core/auth/role_labels.dart';
import 'package:battlegraf_mobile/features/institution/domain/entities/institution_dashboard.dart';
import 'package:battlegraf_mobile/features/institution/presentation/views/institution_hub_view.dart';

void main() {
  test('institutional roles are presented in Spanish', () {
    expect(roleLabel('student'), 'ALUMNO');
    expect(roleLabel('teacher'), 'DOCENTE');
    expect(roleLabel('coordinator'), 'COORDINADOR');
  });

  group('Institution dashboard domain', () {
    test('maps school and every institutional collection', () {
      final dashboard = InstitutionDashboard.fromJson({
        'school_id': 'school-1',
        'viewer_role': 'director',
        'school': {'name': 'IE Piloto', 'code': 'PILOTO'},
        'subscription': {'plan_slug': 'red'},
        'settings': {
          'battle_grades': ['5'],
        },
        'students': [
          {'id': 'student-1'},
        ],
        'sections': [
          {'id': 'section-1'},
        ],
        'subjects': [
          {'id': 'subject-1'},
        ],
        'subject_teachers': const [],
        'staff': const [],
        'classes': const [],
        'enrollments': const [],
        'materials': const [],
        'questions': const [],
        'assignments': const [],
        'battles': const [],
        'ranks': const [],
        'clans': const [],
        'audits': const [],
      });

      expect(dashboard.schoolId, 'school-1');
      expect(dashboard.viewerRole, 'director');
      expect(dashboard.school['name'], 'IE Piloto');
      expect(dashboard.students.single['id'], 'student-1');
      expect(dashboard.sections.single['id'], 'section-1');
      expect(dashboard.subjects.single['id'], 'subject-1');
    });
  });

  group('Institution role navigation', () {
    test('director can access every module', () {
      expect(institutionAreasForRole('director'), InstitutionArea.values);
    });

    test('teacher receives pedagogical modules only', () {
      final areas = institutionAreasForRole('teacher');
      expect(areas, contains(InstitutionArea.profile));
      expect(areas, contains(InstitutionArea.people));
      expect(areas, contains(InstitutionArea.content));
      expect(areas, contains(InstitutionArea.progress));
      expect(areas, isNot(contains(InstitutionArea.school)));
      expect(areas, isNot(contains(InstitutionArea.activity)));
      expect(areas, isNot(contains(InstitutionArea.sections)));
    });

    test('tutor sees the section under their care', () {
      final areas = institutionAreasForRole('tutor');
      expect(areas, contains(InstitutionArea.profile));
      expect(areas, contains(InstitutionArea.sections));
      expect(areas, contains(InstitutionArea.people));
      expect(areas, isNot(contains(InstitutionArea.school)));
      expect(areas, isNot(contains(InstitutionArea.activity)));
    });

    test('student cannot access administrative modules', () {
      final areas = institutionAreasForRole('student');
      expect(areas, [
        InstitutionArea.overview,
        InstitutionArea.profile,
        InstitutionArea.classes,
        InstitutionArea.tasks,
        InstitutionArea.battles,
        InstitutionArea.progress,
      ]);
    });
  });
}
