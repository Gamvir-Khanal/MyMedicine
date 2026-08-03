import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/dose_log.dart';
import '../models/medicine.dart';
import '../models/reminder.dart';

class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smart_medicine_cabinet.db');

    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE dose_logs (
            id TEXT PRIMARY KEY,
            medicineId TEXT,
            medicineName TEXT,
            reminderId TEXT,
            scheduledTime TEXT,
            actualTime TEXT,
            status TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE medicines (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            dosage TEXT,
            form TEXT,
            quantity INTEGER,
            lowStockThreshold INTEGER,
            expiryDate TEXT,
            instructions TEXT,
            createdAt TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE reminders (
            id TEXT PRIMARY KEY,
            medicineId TEXT,
            medicineName TEXT,
            type TEXT,
            frequency TEXT,
            hour INTEGER,
            minute INTEGER,
            daysOfWeek TEXT,
            specificDate TEXT,
            isActive INTEGER,
            note TEXT,
            notificationId INTEGER,
            customSoundPath TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE reminders ADD COLUMN notificationId INTEGER');
          final rows = await db.query('reminders', columns: ['id']);
          for (final row in rows) {
            final id = row['id'] as String;
            await db.update(
              'reminders',
              {'notificationId': id.hashCode & 0x7fffffff},
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE medicines DROP COLUMN imagePath');
          } catch (e) {}
        }
        if (oldVersion < 4) {
          await db
              .execute('ALTER TABLE reminders ADD COLUMN customSoundPath TEXT');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE dose_logs (
              id TEXT PRIMARY KEY,
              medicineId TEXT,
              medicineName TEXT,
              reminderId TEXT,
              scheduledTime TEXT,
              actualTime TEXT,
              status TEXT
            )
          ''');
        }
      },
    );
  }

  Future<void> insertMedicine(Medicine medicine) async {
    final db = await database;
    await db.insert(
      'medicines',
      medicine.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMedicine(Medicine medicine) async {
    final db = await database;
    await db.update(
      'medicines',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  Future<void> deleteMedicine(String id) async {
    final db = await database;
    await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
    await db.delete('reminders', where: 'medicineId = ?', whereArgs: [id]);
  }

  Future<List<Medicine>> getAllMedicines() async {
    final db = await database;
    final maps = await db.query('medicines', orderBy: 'name ASC');
    return maps.map((m) => Medicine.fromMap(m)).toList();
  }

  Future<void> insertReminder(Reminder reminder) async {
    final db = await database;
    await db.insert(
      'reminders',
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateReminder(Reminder reminder) async {
    final db = await database;
    await db.update(
      'reminders',
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<void> deleteReminder(String id) async {
    final db = await database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Reminder>> getAllReminders() async {
    final db = await database;
    final maps = await db.query('reminders');
    return maps.map((m) => Reminder.fromMap(m)).toList();
  }

  Future<void> insertDoseLog(DoseLog log) async {
    final db = await database;
    await db.insert(
      'dose_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DoseLog>> getAllDoseLogs() async {
    final db = await database;
    final maps = await db.query('dose_logs', orderBy: 'scheduledTime DESC');
    return maps.map((m) => DoseLog.fromMap(m)).toList();
  }

  Future<int> getNextNotificationIdBase() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT MAX(notificationId) as maxId FROM reminders');
    final maxId = result.first['maxId'] as int?;
    return maxId == null ? 1000 : maxId + 8;
  }
}
