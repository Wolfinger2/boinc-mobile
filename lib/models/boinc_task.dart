class BoincTask {
  const BoincTask({
    required this.name,
    required this.project,
    required this.appName,
    required this.progress,
    required this.active,
    required this.suspended,
  });

  final String name;
  final String project;
  final String appName;
  final double progress;
  final bool active;
  final bool suspended;
}
