import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/dose_log.dart';
import '../models/medicine.dart';
import '../models/reminder.dart';

/// Manages the local SQLite database for guest-mode users.
///
/// The database is encrypted with AES-256 via SQLCipher.
/// A 64-character hex key is generated randomly on first install
/// and stored in hardware-backed secure storage (Android Keystore / iOS Keychain).
/// Guest data NEVER leaves the device.
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  // ---------------------------------------------------------------------------
  // Encryption key management
  // ---------------------------------------------------------------------------

  static const _keyPrefKey = 'db_enc_key';

  /// Returns the persisted AES key from hardware-backed secure storage (Keystore/Keychain),
  /// or generates and saves a new one on first install.
  /// The key is 64 hex characters (32 bytes = 256-bit AES).
  Future<String> _getOrCreateEncryptionKey() async {
    // Check Hardware-backed Secure Storage first
    var existingKey = await _secureStorage.read(key: _keyPrefKey);

    if (existingKey != null && existingKey.length == 64) {
      return existingKey;
    }

    // Migration check: check if legacy SharedPreferences has the key
    final prefs = await SharedPreferences.getInstance();
    final legacyKey = prefs.getString(_keyPrefKey);

    if (legacyKey != null && legacyKey.length == 64) {
      // Migrate to FlutterSecureStorage and clear legacy preference
      await _secureStorage.write(key: _keyPrefKey, value: legacyKey);
      await prefs.remove(_keyPrefKey);
      return legacyKey;
    }

    // Generate a cryptographically random 32-byte key encoded as hex.
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    final key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _secureStorage.write(key: _keyPrefKey, value: key);
    return key;
  }

  // ---------------------------------------------------------------------------
  // Database initialisation
  // ---------------------------------------------------------------------------

  Future<Database> _initDb() async {
    final encKey = await _getOrCreateEncryptionKey();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smart_medicine_cabinet.db');

    try {
      return await _openEncryptedDb(path, encKey);
    } catch (_) {
      // If the DB exists but can't be opened with the current key (e.g. the
      // prefs key was cleared), delete the corrupted file and start fresh.
      // Guest data is ephemeral by design, so this is safe.
      try {
        await deleteDatabase(path);
      } catch (_) {
        // Ignore errors if the file doesn't exist
      }
      return await _openEncryptedDb(path, encKey);
    }
  }

  Future<Database> _openEncryptedDb(String path, String key) {
    return openDatabase(
      path,
      password: key, // AES-256 encryption via SQLCipher
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ---------------------------------------------------------------------------
  // Schema
  // ---------------------------------------------------------------------------

  Future<void> _onCreate(Database db, int version) async {
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
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
      } catch (e) {
        // SQLite may throw if the column doesn't exist or DROP COLUMN isn't supported
      }
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
  }

  // ---------------------------------------------------------------------------
  // CRUD — Medicines
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // CRUD — Reminders
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // CRUD — Dose Logs
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  Future<int> getNextNotificationIdBase() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT MAX(notificationId) as maxId FROM reminders');
    final maxId = result.first['maxId'] as int?;
    return maxId == null ? 1000 : maxId + 8;
  }
}
