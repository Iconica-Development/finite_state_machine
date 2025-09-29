part of "finite_state_machine.dart";

/// Describes the transition that happens as the result of an action
class FSMTransition {
  FSMTransition({required this.name, required this.targetState});

  final FSMState targetState;
  final String name;

  Future<FSMState> execute(
    FiniteStateMachine stateMachine,
    FSMActionExecution execution,
  ) async {
    var executions = stateMachine._transitionListeners.notifyListeners(
      FSMTransitionIntent(
        transition: this,
        action: execution.action,
        payload: execution.payload,
      ),
    );

    await Future.wait(executions.map((future) async => await future));

    return targetState;
  }
}

// ignore: one_member_abstracts
abstract interface class FSMExecutableAction {
  FutureOr<FSMState?> execute(
    FiniteStateMachine statemachine,
    FSMActionExecution actionExecution,
  );
}

/// The definition of an action
class FSMAction implements FSMExecutableAction {
  FSMAction({required this.name, this.transition});

  final String name;
  final FSMTransition? transition;

  @override
  String toString() {
    var buffer = StringBuffer();
    buffer.write("FSMAction: $name");
    if (transition != null) {
      buffer.writeln();
      buffer.write("Transitions to: ${transition!.name}");
    }
    return buffer.toString();
  }

  @override
  FutureOr<FSMState?> execute(
    FiniteStateMachine stateMachine,
    FSMActionExecution execution,
  ) async {
    var results = await Future.wait(
      stateMachine._actionPredicates
          .notifyListeners(execution)
          .map((future) async => await future),
    );

    // Maybe this should result in an exception, as it will now stop silently.
    // But to have the best possible context, any of the _preActionListeners
    // can still throw an exception
    if (results.any((value) => !value)) return null;

    // Future.wait does not understand the FutureOr, meaning we have to map them
    // and then await them. This does not change the speed, as they will still
    // run in parallel.
    await Future.wait<void>(
      stateMachine._actionHandlers
          .notifyListeners(execution)
          .map((e) async => await e),
    );

    return transition?.execute(stateMachine, execution);
  }
}

/// The definition of the execution of an action
///
/// When an action is performed, the user
class FSMActionExecution {
  FSMActionExecution({
    required this.action,
    required this.fromState,
    required this.payload,
  });

  final FSMAction action;
  final FSMState fromState;
  final dynamic payload;

  @override
  String toString() {
    var buffer = StringBuffer();
    buffer.write("Execution of action: $action");
    buffer.writeln("fromState: $fromState");
    if (payload != null) {
      buffer.writeln();
      buffer.write("payload: $payload");
    }
    return buffer.toString();
  }
}

/// A definition describing which action with what payload lead to which
/// transition.
class FSMTransitionExecution {
  @visibleForTesting
  FSMTransitionExecution({
    required this.action,
    required this.from,
    required this.to,
    required this.payload,
  });

  final FSMAction action;
  final FSMState from;
  final FSMState to;
  final dynamic payload;

  @override
  String toString() {
    var buffer = StringBuffer();
    buffer.writeln("FSMTransition: ${from.name} -> ${to.name}.");
    buffer.write("Caused by: $action");
    if (payload != null) {
      buffer.writeln();
      buffer.write("payload: $payload");
    }
    return buffer.toString();
  }
}

/// A class describing the intent to transition according to the [transition]
class FSMTransitionIntent {
  FSMTransitionIntent({
    required this.transition,
    required this.action,
    required this.payload,
  });

  final FSMTransition transition;
  final FSMAction action;
  final dynamic payload;
}

/// A state object describing a valid state within the state machine.
///
/// The actions are added by the state machine
class FSMState {
  @visibleForTesting
  FSMState({required this.name, required List<FSMAction> allowedActions})
    : _allowedActions = allowedActions;

  final String name;
  final List<FSMAction> _allowedActions;

  /// Retrieve an immutable list of allowed actions
  List<FSMAction> get allowedActions => List.from(_allowedActions);

  /// Validate if the action is allowed for this given state
  bool isActionAllowed(FSMAction action) => _allowedActions.contains(action);

  @override
  String toString() {
    var actions = allowedActions.map((action) => action.name).join("\n\t");
    return "FSMState: $name."
        "\nAllowed actions:\n\t$actions";
  }
}

class FSMIllegalActionException implements Exception {
  FSMIllegalActionException({required this.state, required this.action});

  final FSMState state;
  final FSMAction action;

  @override
  String toString() =>
      "FSMIllegalActionException: Trying to perform "
      "action: $action on "
      "state: $state";
}
