import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const TodoListApp());
}

class TodoItem {
  String text;
  bool isDone;
  DateTime? deadline;

  TodoItem({required this.text, this.isDone = false, this.deadline});

  Map<String, dynamic> toJson() => {
        'text': text,
        'isDone': isDone,
        'deadline': deadline?.toIso8601String(),
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
        text: json['text'],
        isDone: json['isDone'],
        deadline:
            json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      );
}

class TodoListApp extends StatefulWidget {
  const TodoListApp({super.key});

  @override
  State<TodoListApp> createState() => _TodoListAppState();
}

class _TodoListAppState extends State<TodoListApp>
    with SingleTickerProviderStateMixin {
  bool _isDarkMode = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _saveThemePreference(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getBool('isDarkMode');
    if (savedMode != null) {
      setState(() => _isDarkMode = savedMode);
    }
  }

  void _toggleTheme() {
    setState(() => _isDarkMode = !_isDarkMode);
    _saveThemePreference(_isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.lightBlue[100]!;

    return MaterialApp(
      title: 'Todo List',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        ),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: MaterialStatePropertyAll(Colors.teal),
            foregroundColor: MaterialStatePropertyAll(Colors.white),
          ),
        ),
        textTheme: TextTheme(
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.cyanAccent : Colors.teal,
          ),
          bodyMedium: const TextStyle(fontSize: 18),
        ),
      ),
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: baseColor,
            title: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      height: 24,
                    ),
                  ),
                  const Text(
                    'My Day List',
                    style: TextStyle(
                      fontFamily: 'Tageschrift',
                      fontSize: 24.0,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode),
                onPressed: _toggleTheme,
              ),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Tugas'),
                Tab(text: 'Sampah'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              TodoHomePage(isDarkMode: _isDarkMode),
              TrashPage(),
            ],
          ),
        ),
      ),
    );
  }
}

class TodoHomePage extends StatefulWidget {
  final bool isDarkMode;

  const TodoHomePage({super.key, required this.isDarkMode});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  List<TodoItem> _todos = [];
  List<TodoItem> _filteredTodos = [];
  List<TodoItem> _trash = [];
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTodos();
    _searchController.addListener(_filterTodos);
  }

  Future<void> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('todos');
    final trashData = prefs.getString('trash');
    if (data != null) {
      final List decoded = jsonDecode(data);
      _todos = decoded.map((e) => TodoItem.fromJson(e)).toList();
    }
    if (trashData != null) {
      final List decodedTrash = jsonDecode(trashData);
      _trash = decodedTrash.map((e) => TodoItem.fromJson(e)).toList();
    }
    _filteredTodos = List.from(_todos);
    setState(() {});
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'todos', jsonEncode(_todos.map((e) => e.toJson()).toList()));
    await prefs.setString(
        'trash', jsonEncode(_trash.map((e) => e.toJson()).toList()));
  }

  void _addTodo() {
    final text = _taskController.text;
    if (text.isNotEmpty) {
      final item = TodoItem(text: text);
      setState(() {
        _todos.insert(0, item);
        _taskController.clear();
        _filterTodos();
      });
      _saveTodos();
    }
  }

  void _removeTodo(int index) {
    final actual = _filteredTodos[index];
    setState(() {
      _todos.remove(actual);
      _trash.insert(0, actual);
      _filterTodos();
    });
    _saveTodos();
  }

  void _toggleCheck(int index) {
    final item = _filteredTodos[index];
    final actualIndex = _todos.indexOf(item);
    setState(() {
      _todos[actualIndex].isDone = !item.isDone;
      _filterTodos();
    });
    _saveTodos();
  }

  void _filterTodos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTodos =
          _todos.where((t) => t.text.toLowerCase().contains(query)).toList();
    });
  }

  @override
  void dispose() {
    _taskController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Cari Tugas...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _taskController,
                  decoration: const InputDecoration(
                    labelText: 'Tambahkan Tugas',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addTodo(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addTodo,
                child: const Text('Tambah'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _filteredTodos.isEmpty
                ? const Center(child: Text('Tidak ada tugas ditemukan.'))
                : ListView.builder(
                    itemCount: _filteredTodos.length,
                    itemBuilder: (context, index) {
                      final item = _filteredTodos[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Checkbox(
                            value: item.isDone,
                            onChanged: (_) => _toggleCheck(index),
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.text,
                                style: TextStyle(
                                  decoration: item.isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              if (item.deadline != null)
                                Text(
                                  'Deadline: ${item.deadline!.toLocal()}'
                                      .split(' ')[0],
                                  style: const TextStyle(fontSize: 12),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _removeTodo(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  List<TodoItem> _trash = [];

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    final prefs = await SharedPreferences.getInstance();
    final trashData = prefs.getString('trash');
    if (trashData != null) {
      final List decoded = jsonDecode(trashData);
      setState(() {
        _trash = decoded.map((e) => TodoItem.fromJson(e)).toList();
      });
    }
  }

  Future<void> _deleteForever(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _trash.removeAt(index);
    });
    await prefs.setString(
        'trash', jsonEncode(_trash.map((e) => e.toJson()).toList()));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _trash.isEmpty
          ? const Center(child: Text('Keranjang sampah kosong.'))
          : ListView.builder(
              itemCount: _trash.length,
              itemBuilder: (context, index) {
                final item = _trash[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      item.text,
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.redAccent,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_forever),
                      onPressed: () => _deleteForever(index),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
