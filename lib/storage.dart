import 'package:shared_preferences/shared_preferences.dart';

class StorageUtils {
  SharedPreferences _prefs;
  StorageUtils._();

  static final StorageUtils instance = StorageUtils._();

  Future init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future setString({String key, String val}) async {
    return _prefs.setString(key, val);
  }

  Future setDouble({String key, double val}) async {
    return _prefs.setDouble(key, val);
  }

  Future setBool({String key, bool val}) async {
    return _prefs.setBool(key, val);
  }

  Future setInt({String key, int val}) async {
    return _prefs.setInt(key, val);
  }

  Future setStringList({String key, List<String> val}) async {
    return _prefs.setStringList(key, val);
  }

  String getString({String key}) {
    return _prefs.getString(key);
  }

  double getDouble({String key}) {
    return _prefs.getDouble(key);
  }

  bool getBool({String key}) {
    return _prefs.getBool(key);
  }

  int getInt({String key}) {
    return _prefs.getInt(key);
  }

  Object getObj({String key}) {
    return _prefs.get(key);
  }

  List<String> getStringList({String key}) {
    return _prefs.getStringList(key);
  }

  Set<String> getListKeys() {
    return _prefs.getKeys();
  }

  Future<bool> removeKey({String key}) {
    return _prefs.remove(key);
  }

  Future<bool> clearAllKeys() {
    return _prefs.clear();
  }

  bool containsKey({String key}) {
    return _prefs.containsKey(key);
  }

  Future reloadAll() {
    return _prefs.reload();
  }
}
