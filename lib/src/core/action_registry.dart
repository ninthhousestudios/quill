/// Registry mapping action names to callbacks.
///
/// Pure Dart — no Flutter dependencies.
class ActionRegistry {
  final Map<String, void Function()> _actions = {};

  /// Register [callback] under [name].
  ///
  /// Throws [ArgumentError] if [name] is already registered.
  void register(String name, void Function() callback) {
    if (_actions.containsKey(name)) {
      throw ArgumentError('Action "$name" is already registered.');
    }
    _actions[name] = callback;
  }

  /// Bulk-register a map of name → callback pairs.
  ///
  /// Throws [ArgumentError] on the first name that is already registered.
  void registerAll(Map<String, void Function()> actions) {
    for (final entry in actions.entries) {
      register(entry.key, entry.value);
    }
  }

  /// Invoke the action named [name].
  ///
  /// Returns `true` if the action was found and invoked, `false` if not found.
  bool invoke(String name) {
    final callback = _actions[name];
    if (callback == null) return false;
    callback();
    return true;
  }

  /// Remove the action named [name]. No-op if not registered.
  void unregister(String name) {
    _actions.remove(name);
  }

  /// Returns `true` if an action named [name] is registered.
  bool has(String name) => _actions.containsKey(name);

  /// All currently registered action names.
  Set<String> get registeredNames => _actions.keys.toSet();
}
