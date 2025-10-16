import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  runApp(const StudyPlannerApp());
}

class StudyPlannerApp extends StatelessWidget {
  const StudyPlannerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Study Planner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// Task Model
class Task {
  String id;
  String title;
  String description;
  DateTime dueDate;
  TimeOfDay? reminderTime;
  bool isCompleted;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.dueDate,
    this.reminderTime,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'reminderTime': reminderTime != null
          ? '${reminderTime!.hour}:${reminderTime!.minute}'
          : null,
      'isCompleted': isCompleted,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    TimeOfDay? reminder;
    if (json['reminderTime'] != null) {
      final parts = json['reminderTime'].split(':');
      reminder = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      dueDate: DateTime.parse(json['dueDate']),
      reminderTime: reminder,
      isCompleted: json['isCompleted'] ?? false,
    );
  }
}

// Storage Service
class StorageService {
  static const String _tasksKey = 'tasks';
  static const String _remindersEnabledKey = 'reminders_enabled';

  Future<List<Task>> getTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksJson = prefs.getString(_tasksKey);

    if (tasksJson == null) return [];

    final List<dynamic> tasksList = jsonDecode(tasksJson);
    return tasksList.map((json) => Task.fromJson(json)).toList();
  }

  Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final String tasksJson = jsonEncode(
      tasks.map((task) => task.toJson()).toList(),
    );
    await prefs.setString(_tasksKey, tasksJson);
  }

  Future<bool> getRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_remindersEnabledKey) ?? true;
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_remindersEnabledKey, enabled);
  }
}

// Main Screen with Bottom Navigation
class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final StorageService _storage = StorageService();
  List<Task> _tasks = [];
  bool _remindersEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkReminders();
  }

  Future<void> _loadData() async {
    final tasks = await _storage.getTasks();
    final remindersEnabled = await _storage.getRemindersEnabled();
    setState(() {
      _tasks = tasks;
      _remindersEnabled = remindersEnabled;
    });
  }

  void _checkReminders() async {
    if (!_remindersEnabled) return;

    final tasks = await _storage.getTasks();
    final now = DateTime.now();

    for (var task in tasks) {
      if (task.reminderTime != null && !task.isCompleted) {
        final taskDateTime = DateTime(
          task.dueDate.year,
          task.dueDate.month,
          task.dueDate.day,
          task.reminderTime!.hour,
          task.reminderTime!.minute,
        );

        if (now.isAfter(taskDateTime) &&
            now.difference(taskDateTime).inMinutes < 60) {
          _showReminderDialog(task);
        }
      }
    }
  }

  void _showReminderDialog(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task Reminder'),
        content: Text('Reminder for: ${task.title}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToEditTask(task);
            },
            child: const Text('View Task'),
          ),
        ],
      ),
    );
  }

  void _navigateToEditTask(Task task) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditTaskScreen(task: task),
      ),
    );

    if (result != null) {
      _loadData();
    }
  }

  void _updateReminders(bool value) async {
    setState(() {
      _remindersEnabled = value;
    });
    await _storage.setRemindersEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      TodayScreen(tasks: _tasks, onRefresh: _loadData),
      CalendarScreen(tasks: _tasks, onRefresh: _loadData),
      SettingsScreen(
        remindersEnabled: _remindersEnabled,
        onRemindersChanged: _updateReminders,
        taskCount: _tasks.length,
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.today),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _currentIndex != 2
          ? FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditTaskScreen(),
            ),
          );
          if (result != null) {
            _loadData();
          }
        },
        child: const Icon(Icons.add),
      )
          : null,
    );
  }
}

// Today Screen
class TodayScreen extends StatelessWidget {
  final List<Task> tasks;
  final VoidCallback onRefresh;

  const TodayScreen({
    Key? key,
    required this.tasks,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayTasks = tasks.where((task) {
      return task.dueDate.year == today.year &&
          task.dueDate.month == today.month &&
          task.dueDate.day == today.day;
    }).toList();

    todayTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
      ),
      body: todayTasks.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 100,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks for today!',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: todayTasks.length,
        itemBuilder: (context, index) {
          return TaskCard(
            task: todayTasks[index],
            onRefresh: onRefresh,
          );
        },
      ),
    );
  }
}

// Calendar Screen
class CalendarScreen extends StatefulWidget {
  final List<Task> tasks;
  final VoidCallback onRefresh;

  const CalendarScreen({
    Key? key,
    required this.tasks,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final selectedTasks = _selectedDay != null
        ? widget.tasks.where((task) {
      return task.dueDate.year == _selectedDay!.year &&
          task.dueDate.month == _selectedDay!.month &&
          task.dueDate.day == _selectedDay!.day;
    }).toList()
        : <Task>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: (day) {
              return widget.tasks.where((task) {
                return task.dueDate.year == day.year &&
                    task.dueDate.month == day.month &&
                    task.dueDate.day == day.day;
              }).toList();
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blue[200],
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: _selectedDay == null
                ? const Center(
              child: Text('Select a date to view tasks'),
            )
                : selectedTasks.isEmpty
                ? const Center(
              child: Text('No tasks for this date'),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: selectedTasks.length,
              itemBuilder: (context, index) {
                return TaskCard(
                  task: selectedTasks[index],
                  onRefresh: widget.onRefresh,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Task Card Widget
class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onRefresh;

  const TaskCard({
    Key? key,
    required this.task,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final storage = StorageService();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (value) async {
            task.isCompleted = value ?? false;
            final tasks = await storage.getTasks();
            final index = tasks.indexWhere((t) => t.id == task.id);
            if (index != -1) {
              tasks[index] = task;
              await storage.saveTasks(tasks);
              onRefresh();
            }
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty)
              Text(task.description),
            Text(
              'Due: ${DateFormat('MMM dd, yyyy').format(task.dueDate)}',
              style: const TextStyle(fontSize: 12),
            ),
            if (task.reminderTime != null)
              Text(
                'Reminder: ${task.reminderTime!.format(context)}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Text('Edit'),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
          onSelected: (value) async {
            if (value == 'edit') {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddEditTaskScreen(task: task),
                ),
              );
              if (result != null) {
                onRefresh();
              }
            } else if (value == 'delete') {
              final tasks = await storage.getTasks();
              tasks.removeWhere((t) => t.id == task.id);
              await storage.saveTasks(tasks);
              onRefresh();
            }
          },
        ),
      ),
    );
  }
}

// Add/Edit Task Screen
class AddEditTaskScreen extends StatefulWidget {
  final Task? task;

  const AddEditTaskScreen({Key? key, this.task}) : super(key: key);

  @override
  State<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends State<AddEditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _dueDate;
  TimeOfDay? _reminderTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.task?.description ?? '',
    );
    _dueDate = widget.task?.dueDate ?? DateTime.now();
    _reminderTime = widget.task?.reminderTime;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Add Task' : 'Edit Task'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveTask,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Due Date *'),
              subtitle: Text(DateFormat('MMM dd, yyyy').format(_dueDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() => _dueDate = date);
                }
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              title: const Text('Reminder Time (Optional)'),
              subtitle: Text(_reminderTime != null
                  ? _reminderTime!.format(context)
                  : 'Not set'),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _reminderTime ?? TimeOfDay.now(),
                );
                if (time != null) {
                  setState(() => _reminderTime = time);
                }
              },
            ),
            if (_reminderTime != null)
              TextButton(
                onPressed: () {
                  setState(() => _reminderTime = null);
                },
                child: const Text('Clear Reminder'),
              ),
          ],
        ),
      ),
    );
  }

  void _saveTask() async {
    if (_formKey.currentState!.validate()) {
      final storage = StorageService();
      final tasks = await storage.getTasks();

      final task = Task(
        id: widget.task?.id ?? DateTime.now().toString(),
        title: _titleController.text,
        description: _descriptionController.text,
        dueDate: _dueDate,
        reminderTime: _reminderTime,
        isCompleted: widget.task?.isCompleted ?? false,
      );

      if (widget.task == null) {
        tasks.add(task);
      } else {
        final index = tasks.indexWhere((t) => t.id == widget.task!.id);
        if (index != -1) {
          tasks[index] = task;
        }
      }

      await storage.saveTasks(tasks);
      Navigator.pop(context, true);
    }
  }
}

// Settings Screen
class SettingsScreen extends StatelessWidget {
  final bool remindersEnabled;
  final Function(bool) onRemindersChanged;
  final int taskCount;

  const SettingsScreen({
    Key? key,
    required this.remindersEnabled,
    required this.onRemindersChanged,
    required this.taskCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Enable Reminders'),
            subtitle: const Text('Show reminder dialogs when app opens'),
            value: remindersEnabled,
            onChanged: onRemindersChanged,
          ),
          const Divider(),
          ListTile(
            title: const Text('Storage Method'),
            subtitle: const Text('SharedPreferences'),
            leading: const Icon(Icons.storage),
          ),
          ListTile(
            title: const Text('Total Tasks'),
            subtitle: Text('$taskCount tasks stored'),
            leading: const Icon(Icons.task),
          ),
          const Divider(),
          ListTile(
            title: const Text('About'),
            subtitle: const Text('Study Planner App v1.0'),
            leading: const Icon(Icons.info),
          ),
          ListTile(
            title: const Text('Clear All Data'),
            leading: const Icon(Icons.delete_forever),
            textColor: Colors.red,
            iconColor: Colors.red,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Data?'),
                  content: const Text(
                    'This will delete all tasks. This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final storage = StorageService();
                await storage.saveTasks([]);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All data cleared')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}