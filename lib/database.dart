import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get contextText => text().nullable()();
  TextColumn get contextName => text().nullable()();
  TextColumn get contextType => text().nullable()(); // 'pdf', 'docx', etc.

  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id)();
  TextColumn get role => text()();
  TextColumn get content => text()();
  TextColumn get images => text().nullable()(); // JSON string
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Sessions, Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase()
      : super(driftDatabase(
          name: 'govgen_db',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration=> MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Add context fields for the first time
        await m.addColumn(sessions, sessions.contextText);
        await m.addColumn(sessions, sessions.contextName);
        await m.addColumn(sessions, sessions.contextType);
      }
      // Migration from v2 to v3: ensure all context columns exist
      if (from < 3) {
        try {
          await m.addColumn(sessions, sessions.contextText);
        } catch (e) { /* column may exist */ }
        try {
          await m.addColumn(sessions, sessions.contextName);
        } catch (e) { /* column may exist */ }
        try {
          await m.addColumn(sessions, sessions.contextType);
        } catch (e) { /* column may exist */ }
      }
    },
  );

  // CRUD for Sessions
  Future<List<Session>> getAllSessions() => select(sessions).get();
  Future<int> insertSession(SessionsCompanion session) => into(sessions).insert(session);
  Future<bool> updateSession(SessionsCompanion session) => update(sessions).replace(session);
  Future<int> updateSessionTitle(String id, String title) =>
      (update(sessions)..where((t) => t.id.equals(id))).write(SessionsCompanion(title: Value(title)));

  Future<int> updateSessionContext(String id, String? contextText, String? contextName, String? contextType) =>
      (update(sessions)..where((t) => t.id.equals(id))).write(
        SessionsCompanion(
          contextText: Value(contextText),
          contextName: Value(contextName),
          contextType: Value(contextType),
        ),
      );

  Future<int> deleteSession(String id) => (delete(sessions)..where((t) => t.id.equals(id))).go();

  // CRUD for Messages
  Future<List<Message>> getMessagesForSession(String sessionId) =>
      (select(messages)..where((t) => t.sessionId.equals(sessionId))).get();
  Future<int> insertMessage(MessagesCompanion message) => into(messages).insert(message);
  Future<int> deleteMessagesForSession(String sessionId) =>
      (delete(messages)..where((t) => t.sessionId.equals(sessionId))).go();
}


