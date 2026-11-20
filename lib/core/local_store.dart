import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../features/expenses/model.dart';

class LocalStore {
  LocalStore._();
  static final instance = LocalStore._();
  Database? _db;
  final session = ValueNotifier<int?>(null);
  bool demo = false;
  Future<Database> get database async => _db ??= await openDatabase(
    p.join(await getDatabasesPath(), 'kech.db'),
    version: 1,
    onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    onCreate: (db, version) async {
      await db.execute(
        'CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL, surname TEXT NOT NULL, email TEXT NOT NULL UNIQUE, username TEXT UNIQUE, business INTEGER NOT NULL, business_name TEXT, salt BLOB NOT NULL, hash BLOB NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE expenses (id INTEGER PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE, cents INTEGER NOT NULL, concept TEXT NOT NULL, date TEXT NOT NULL, merchant TEXT NOT NULL, category TEXT NOT NULL, payment TEXT NOT NULL, reference TEXT NOT NULL, parts TEXT NOT NULL, image BLOB, recognized_text TEXT, suggested_total TEXT, suggested_date TEXT, suggested_payment TEXT, suggested_merchant TEXT, suggested_reference TEXT, suggested_category TEXT)',
      );
    },
  );
  Future<Uint8List> _hash(String password, List<int> salt) async {
    final key = await Argon2id(
      parallelism: 1,
      memory: 19456,
      iterations: 2,
      hashLength: 32,
    ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
    return Uint8List.fromList(await key.extractBytes());
  }

  Future<void> register({
    required String name,
    required String surname,
    required String email,
    required String username,
    required String password,
    required bool business,
    required String businessName,
  }) async {
    final rng = Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
    final digest = await compute(_derive, (password, salt));
    final db = await database;
    await db.insert('users', {
      'name': name.trim(),
      'surname': surname.trim(),
      'email': email.trim().toLowerCase(),
      'username': username.trim().isEmpty
          ? null
          : username.trim().toLowerCase(),
      'business': business ? 1 : 0,
      'business_name': business ? businessName.trim() : null,
      'salt': salt,
      'hash': digest,
    });
  }

  static Future<Uint8List> _derive((String, Uint8List) args) =>
      LocalStore.instance._hash(args.$1, args.$2);
  Future<bool> login(String identifier, String password) async {
    final db = await database;
    final id = identifier.trim().toLowerCase();
    final rows = await db.query(
      'users',
      where: 'email = ? OR username = ?',
      whereArgs: [id, id],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final row = rows.single;
    final hash = await compute(_derive, (password, row['salt'] as Uint8List));
    final expected = row['hash'] as Uint8List;
    var diff = hash.length ^ expected.length;
    for (var i = 0; i < hash.length && i < expected.length; i++) {
      diff |= hash[i] ^ expected[i];
    }
    if (diff != 0) return false;
    demo = false;
    session.value = row['id'] as int;
    return true;
  }

  void enterDemo() {
    demo = true;
    session.value = -1;
  }

  void logout() {
    demo = false;
    session.value = null;
  }

  Future<List<Expense>> loadExpenses(int id) async {
    if (id == -1) return [];
    final rows = await (await database).query(
      'expenses',
      where: 'user_id = ?',
      whereArgs: [id],
      orderBy: 'id DESC',
    );
    return rows
        .map(
          (r) => Expense(
            cents: r['cents'] as int,
            concept: r['concept'] as String,
            date: DateTime.parse(r['date'] as String),
            merchant: r['merchant'] as String,
            category: r['category'] as String,
            payment: r['payment'] as String,
            reference: r['reference'] as String,
            parts: Map<String, int>.from(jsonDecode(r['parts'] as String)),
            image: r['image'] as Uint8List?,
            recognizedText: r['recognized_text'] as String?,
            suggestedTotal: r['suggested_total'] as String?,
            suggestedDate: r['suggested_date'] == null
                ? null
                : DateTime.parse(r['suggested_date'] as String),
            suggestedPayment: r['suggested_payment'] as String?,
            suggestedMerchant: r['suggested_merchant'] as String?,
            suggestedReference: r['suggested_reference'] as String?,
            suggestedCategory: r['suggested_category'] as String?,
          ),
        )
        .toList();
  }

  Future<void> saveExpense(int id, Expense e) async {
    if (id == -1) return;
    await (await database).insert('expenses', {
      'user_id': id,
      'cents': e.cents,
      'concept': e.concept,
      'date': e.date.toIso8601String(),
      'merchant': e.merchant,
      'category': e.category,
      'payment': e.payment,
      'reference': e.reference,
      'parts': jsonEncode(e.parts),
      'image': e.image,
      'recognized_text': e.recognizedText,
      'suggested_total': e.suggestedTotal,
      'suggested_date': e.suggestedDate?.toIso8601String(),
      'suggested_payment': e.suggestedPayment,
      'suggested_merchant': e.suggestedMerchant,
      'suggested_reference': e.suggestedReference,
      'suggested_category': e.suggestedCategory,
    });
  }
}
