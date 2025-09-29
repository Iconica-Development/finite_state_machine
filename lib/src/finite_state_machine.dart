import "dart:async";

import "package:meta/meta.dart";

part "transition.dart";
part "listenable_manager.dart";

/// A state machine that is configure with finite states
///
/// Each [FSMState] defines a set of [FSMAction]s, and each action has an
/// optional [FSMExecutableTransition]. The [FSMExecutableTransition] object is
/// only the act of moving from one state to another.
class FiniteStateMachine {
  /// An in memory list of all possible states
  final Map<String, FSMState> _states = {};

  /// A manager for all listeners regarding state changes.
  late final ListenableManager<FSMState, void> _stateListeners =
      ListenableManager<FSMState, void>();

  /// A manager for all listeners subscribed to state enters during transitions
  late final ListenableManager<FSMTransitionExecution, void>
  _enterStateListeners = ListenableManager<FSMTransitionExecution, void>();

  /// A manager for all listeners subscribed to state exits during transitions
  late final ListenableManager<FSMTransitionExecution, void>
  _exitStateListeners = ListenableManager<FSMTransitionExecution, void>();

  /// A manager for all listeners subscribed to transitions
  late final ListenableManager<FSMTransitionIntent, FutureOr<void>>
  _transitionListeners =
      ListenableManager<FSMTransitionIntent, FutureOr<void>>();

  /// A manager for all pre-action checks
  late final ListenableManager<FSMActionExecution, FutureOr<bool>>
  _actionPredicates = ListenableManager<FSMActionExecution, FutureOr<bool>>();

  /// A manager for all handlers that run when an action is called
  late final ListenableManager<FSMActionExecution, FutureOr<void>>
  _actionHandlers = ListenableManager<FSMActionExecution, FutureOr<void>>();

  /// An internal reference to listeners
  late final _listeners = [
    _stateListeners,
    _enterStateListeners,
    _exitStateListeners,
    _actionPredicates,
    _actionHandlers,
    _transitionListeners,
  ];

  FSMState get current {
    if (_current == null) {
      throw StateError(
        "Cannot get the current state of a state machine that has not started",
      );
    }
    return _current!;
  }

  FSMState? _current;

  /// Starts the current state machine
  ///
  /// At this point, no other states can be added and the state machine is
  /// locked.
  void start(FSMState initialState) {
    if (_current != null) {
      throw StateError("Cannot start an already started state machine");
    }
    _setState(initialState);
  }

  void _setState(FSMState state) {
    _current = state;
    _stateListeners.notifyListeners(current);
  }

  /// Adds a new state
  FSMState addState(String name) {
    var state = FSMState(name: name, allowedActions: []);
    if (_current != null) {
      throw StateError("Cannot add states to an already started state machine");
    }
    if (_states.containsKey(state.name)) {
      throw StateError("State already exists with this name: ${state.name}");
    }

    return _states[state.name] = state;
  }

  /// Adds an action to a specific set of states
  void addAction(List<FSMState> states, FSMAction action) {
    if (action.transition != null &&
        !_states.containsKey(action.transition?.targetState.name)) {
      throw StateError("You cannot define a transition to an unknown state");
    }
    for (var state in states) {
      _addAction(state, action);
    }
  }

  void _addAction(FSMState state, FSMAction action) {
    if (!_states.containsKey(state.name)) return;
    _states[state.name]!._allowedActions.add(action);
  }

  /// Adds an action to all possible states
  /// This does not consider future states.
  ///
  /// Calling [addState] after this one will not also assign this action to
  /// that state.
  void addBlanketAction(FSMAction action) {
    addAction(_states.values.toList(), action);
  }

  List<FSMAction> getAllowedActions(FSMState state) {
    if (!_states.containsKey(state.name)) return [];
    return _states[state.name]!.allowedActions;
  }

  // ignore: avoid_annotating_with_dynamic
  Future<void> callAction(FSMAction action, [dynamic payload]) async {
    var state = current;
    if (!state.isActionAllowed(action)) {
      throw FSMIllegalActionException(state: current, action: action);
    }

    var targetState = await action.execute(
      this,
      FSMActionExecution(action: action, payload: payload, fromState: state),
    );

    if (targetState == null) return;

    var transition = FSMTransitionExecution(
      from: state,
      to: targetState,
      payload: payload,
      action: action,
    );

    if (state != current) return;

    // check if transition is allowed
    _exitStateListeners.notifyListeners(transition);
    _setState(targetState);
    _enterStateListeners.notifyListeners(transition);
  }

  /// Adds a listener which is notifier when a state is entered
  void onEnterState({
    required void Function(FSMTransitionExecution transition) onEnterState,
    FSMState? state,
  }) {
    if (state == null) {
      _enterStateListeners.addListener(onEnterState);
      return;
    }

    _enterStateListeners.listenIf(
      onEnterState,
      (transition) => transition.to.name == state.name,
    );
  }

  /// Adds a listener which is notifier when a state is left
  void onExitState({
    required void Function(FSMTransitionExecution transition) onExitState,
    FSMState? state,
  }) {
    if (state == null) {
      _exitStateListeners.addListener(onExitState);
      return;
    }

    _exitStateListeners.listenIf(
      onExitState,
      (transition) => transition.from.name == state.name,
    );
  }

  /// Add a function that is run before an action starts, with the option to
  /// interrupt said action.
  ///
  /// All action checks are ran in parallel and order cannot be guaranteed.
  void addActionPredicate({
    required FutureOr<bool> Function(FSMActionExecution execution) onAction,
    FSMAction? action,
  }) {
    if (action == null) {
      _actionPredicates.addListener(onAction);
      return;
    }

    _actionPredicates.listenIf(
      onAction,
      (execution) => execution.action.name == action.name,
    );
  }

  /// Add a listener that is executed immediately after an action is deemed
  /// ok for a given state and the checks provided through [addActionPredicate]
  ///
  /// Any listeners returning a future will be awaited in parallel of each
  /// other. When all are finished only then a transition will happen if any
  /// are defined.
  void onAction({
    required FutureOr<void> Function(FSMActionExecution execution) onAction,
    FSMAction? action,
  }) {
    if (action == null) {
      _actionHandlers.addListener(onAction);
      return;
    }

    _actionHandlers.listenIf(
      onAction,
      (execution) => execution.action.name == action.name,
    );
  }

  /// Add a listener to whenever a transition has happened
  void onTransition({
    required FutureOr<void> Function(FSMTransitionIntent transition)
    onTransition,
    FSMTransition? transition,
  }) {
    if (transition == null) {
      _transitionListeners.addListener(onTransition);
      return;
    }
    _transitionListeners.listenIf(
      onTransition,
      (t) => t.transition.name == transition.name,
    );
  }

  /// Add a listener to whenever the state machine changes state
  ///
  /// If this listener is called, [current] will read that exact state
  void onStateChanged(void Function(FSMState state) onStateChanged) {
    _stateListeners.addListener(onStateChanged);
  }

  /// Removes any listener, will automatically determine if the given listener
  /// is any of the possible listeners on this state machine.
  ///
  /// Unlike creating a listener, you do not need to provide which type of event
  /// you wanted to listen to when removing the listener
  void removeListener<T, R>(ValueListener<T, R> listener) {
    for (var listenable in _listeners) {
      listenable.removeListener(listener);
    }
  }

  /// Removes a list of listeners, will automatically determine if the given
  /// listener is any of the possible listeners on this state machine.
  ///
  /// Unlike creating a listener, you do not need to provide which type of event
  /// you wanted to listen to when removing the listener
  void removeListeners<T, R>(List<ValueListener<T, R>> listeners) {
    for (var listener in listeners) {
      removeListener<T, R>(listener);
    }
  }

  /// Disposes all listeners internally
  void dispose() {
    for (var listener in _listeners) {
      listener.dispose();
    }
  }
}
