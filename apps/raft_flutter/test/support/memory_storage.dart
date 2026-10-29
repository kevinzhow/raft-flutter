import 'package:raft_flutter/data/search_memory.dart';

/// In-memory [SearchMemoryStorage] for tests that must not touch preferences.
class MemoryStorage implements SearchMemoryStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}
