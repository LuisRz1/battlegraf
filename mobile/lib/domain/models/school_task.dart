class SchoolTask {
  final String id;
  final String sectionId;
  final String subject;
  final String title;
  final String description;
  final String taskType;
  final DateTime? dueDate;
  final int xpReward;
  final String status;
  final Map<String, String> options;
  final String? correctOption;

  const SchoolTask({
    required this.id,
    required this.sectionId,
    required this.subject,
    required this.title,
    required this.description,
    required this.taskType,
    required this.xpReward,
    required this.status,
    this.dueDate,
    this.options = const {},
    this.correctOption,
  });

  factory SchoolTask.fromJson(Map<String, dynamic> json) {
    return SchoolTask(
      id: json['id'].toString(),
      sectionId: json['section_id'].toString(),
      subject: json['subject'].toString(),
      title: json['title'].toString(),
      description: json['description']?.toString() ?? '',
      taskType: json['task_type'].toString(),
      dueDate: json['due_date'] == null
          ? null
          : DateTime.tryParse(json['due_date'].toString()),
      xpReward: json['xp_reward'] as int? ?? 0,
      status: json['status'].toString(),
      options: (json['options'] as Map<String, dynamic>? ?? const {}).map(
        (key, value) => MapEntry(key, value.toString()),
      ),
      correctOption: json['correct_option']?.toString(),
    );
  }
}

class TaskSubmission {
  final String id;
  final String taskId;
  final bool isGraded;
  final int? score;
  final int xpAwarded;
  final String feedback;

  const TaskSubmission({
    required this.id,
    required this.taskId,
    required this.isGraded,
    required this.xpAwarded,
    required this.feedback,
    this.score,
  });

  factory TaskSubmission.fromJson(Map<String, dynamic> json) {
    return TaskSubmission(
      id: json['id'].toString(),
      taskId: json['task_id'].toString(),
      isGraded: json['is_graded'] == true,
      score: json['score'] as int?,
      xpAwarded: json['xp_awarded'] as int? ?? 0,
      feedback: json['feedback']?.toString() ?? '',
    );
  }
}
