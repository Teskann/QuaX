import 'package:quax/database/repository.dart';

Future<List<Map<String, Object?>>> getAccounts() async {
  var database = await Repository.readOnly();
  return database.query(tableAccounts);
}