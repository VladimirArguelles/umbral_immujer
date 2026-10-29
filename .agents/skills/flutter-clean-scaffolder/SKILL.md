---
name: flutter-clean-scaffolder
description: Scaffolds and enforces Clean Architecture directory structures, domain models, repositories, use cases, and presentation layers in Flutter applications. Use when creating new features, refactoring existing modules, organizing state management (Riverpod/BLoC/Provider), or separating business logic from UI code.
---

# Flutter Clean Architecture Scaffolder

This skill guides the scaffolding and implementation of production-grade **Clean Architecture** modules in Flutter applications.

## Core Architectural Blueprint

Each feature or module must be organized into strictly decoupled layers:

```text
lib/features/<feature_name>/
├── data/
│   ├── datasources/        # Remote/local APIs (Supabase, HTTP, SQLite, SharedPrefs)
│   ├── models/             # Data transfer objects with fromJson / toJson / copyWith
│   └── repositories/       # Concrete implementation of domain repository interfaces
├── domain/
│   ├── models/             # Pure Dart entity definitions (immutable, no framework dependencies)
│   ├── repositories/       # Abstract repository interfaces (contracts)
│   └── usecases/           # Single-responsibility business logic interactors
└── presentation/
    ├── controllers/        # State notifiers, Cubits, BLoCs, or ChangeNotifier
    ├── pages/ (or screens/)# Top-level view widgets, Scaffold, route endpoints
    └── widgets/            # Reusable private or sub-components of the screen
```

---

## Operating Principles

1. **Dependency Inversion**:
   * Domain layer **never** imports Data or Presentation.
   * Data and Presentation layers depend on Domain contracts.
2. **Immutability**:
   * Domain entities and Value Objects must be immutable (`@immutable`, `final` fields).
   * Models use factory constructors (`fromJson`) and explicit mapping to domain entities.
3. **Fail Fast with Typed Results**:
   * Asynchronous repository operations must return predictable Result/Either types or clear domain exceptions rather than leaking raw backend HTTP/Postgres errors.
4. **State Separation**:
   * Presentation widgets must remain declarative and thin. Never place direct network calls or complex query joins inside `build()` or `onPressed()`.

---

## Standard Scaffolding Templates

### 1. Domain Entity (`domain/models/<entity>.dart`)
```dart
import 'package:flutter/foundation.dart';

@immutable
class ExampleItem {
  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;

  const ExampleItem({
    required this.id,
    required this.name,
    this.isActive = true,
    required this.createdAt,
  });

  ExampleItem copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return ExampleItem(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
```

### 2. Domain Contract (`domain/repositories/<entity>_repository.dart`)
```dart
import '../models/example_item.dart';

abstract class ExampleRepository {
  Future<List<ExampleItem>> getItems();
  Future<ExampleItem> getById(String id);
  Future<void> saveItem(ExampleItem item);
  Stream<List<ExampleItem>> watchItems();
}
```

### 3. Data Repository (`data/repositories/supabase_example_repository.dart`)
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/models/example_item.dart';
import '../../domain/repositories/example_repository.dart';

class SupabaseExampleRepository implements ExampleRepository {
  final SupabaseClient _client;

  SupabaseExampleRepository(this._client);

  @override
  Future<List<ExampleItem>> getItems() async {
    final response = await _client
        .from('items')
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => ExampleItem(
              id: json['id'] as String,
              name: (json['name'] ?? '') as String,
              isActive: (json['is_active'] ?? true) as bool,
              createdAt: DateTime.parse(json['created_at'] as String),
            ))
        .toList();
  }

  @override
  Future<ExampleItem> getById(String id) async {
    final response = await _client
        .from('items')
        .select()
        .eq('id', id)
        .single();

    return ExampleItem(
      id: response['id'] as String,
      name: (response['name'] ?? '') as String,
      isActive: (response['is_active'] ?? true) as bool,
      createdAt: DateTime.parse(response['created_at'] as String),
    );
  }

  @override
  Future<void> saveItem(ExampleItem item) async {
    await _client.from('items').upsert({
      'id': item.id,
      'name': item.name,
      'is_active': item.isActive,
    });
  }

  @override
  Stream<List<ExampleItem>> watchItems() {
    return _client
        .from('items')
        .stream(primaryKey: ['id'])
        .map((rows) => rows
            .map((json) => ExampleItem(
                  id: json['id'] as String,
                  name: (json['name'] ?? '') as String,
                  isActive: (json['is_active'] ?? true) as bool,
                  createdAt: DateTime.parse(json['created_at'] as String),
                ))
            .toList());
  }
}
```

---

## Checklist When Adding a New Feature
- [ ] Create domain entity and abstract repository interface.
- [ ] Implement data layer repository calling datasource/Supabase.
- [ ] Bind state management in presentation layer.
- [ ] Keep presentation widgets modular and testable with mock repository data.
- [ ] Run `flutter analyze` and `flutter test` after scaffolding.
