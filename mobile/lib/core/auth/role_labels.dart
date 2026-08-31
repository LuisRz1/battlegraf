String roleLabel(String role) => switch (role.toLowerCase()) {
  'owner' => 'PROPIETARIO',
  'director' => 'DIRECTOR',
  'subdirector' => 'SUBDIRECTOR',
  'coordinator' => 'COORDINADOR',
  'tutor' => 'TUTOR',
  'teacher' || 'professor' => 'DOCENTE',
  'student' => 'ALUMNO',
  _ => role.toUpperCase(),
};
