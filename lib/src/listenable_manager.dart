part of "finite_state_machine.dart";

/// A listener that is called when value of type [T] is changed.
///
/// If the results are collected, the return type [R] is used.
typedef ValueListener<T, R> = R Function(T);

/// A utility class for managing listeners for a specific type of value [T]
///
/// If you want to collect the results of all listeners, define [R] to be
/// something other than void and capture the response of [notifyListeners] in
/// a variable.
class ListenableManager<T, R> {
  final List<ValueListener<T, R?>> _valueListeners = [];
  final Map<ValueListener<T, R>, ValueListener<T, R?>> _filters = {};

  /// Adds a listener to the current set of listeners.
  ///
  /// In case a listener depends on the state of the value, you can use a
  /// conditional listener, through [listenIf].
  void addListener(ValueListener<T, R> onValue) {
    _valueListeners.add(onValue);
  }

  /// removes a listener if it exists directly or indirectly as a conditional.
  void removeListener(Function onValue) {
    if (_filters.containsKey(onValue)) {
      _valueListeners.remove(_filters.remove(onValue));
      return;
    }

    _valueListeners.remove(onValue);
  }

  /// Adds a listener based on a conditional [predicate].
  ///
  /// To remove this listener, simply call [removeListener] just like you would
  /// for a normal [addListener] call.
  void listenIf(ValueListener<T, R> onValue, bool Function(T) predicate) {
    R? handleValueChange(T value) {
      if (predicate(value)) {
        return onValue(value);
      }

      return null;
    }

    _filters[onValue] = handleValueChange;
    _valueListeners.add(handleValueChange);
  }

  /// Notifies all listeners with the provided value
  List<R> notifyListeners(T value) =>
      _valueListeners
          .map((action) => action.call(value))
          .whereType<R>()
          .toList();

  void dispose() {
    _valueListeners.clear();
    _filters.clear();
  }
}
