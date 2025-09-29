import "dart:io";

import "package:finite_state_machine/finite_state_machine.dart";

void main(List<String> args) async {
  // Create a new state machine
  var stateMachine = FiniteStateMachine();

  // Define states
  var ready = stateMachine.addState("ready");

  // Define transitions
  var toVending = FSMTransition(name: "to_vending", targetState: ready);

  // Define actions
  var vend = FSMAction(name: "vend", transition: toVending);

  stateMachine.addAction([ready], vend);

  // Start the state machine in the 'ready' state
  stateMachine.start(ready);

  // Listen for transitions
  void printTransition(FSMTransitionIntent transition) {
    stdout.writeln("Transition: $transition");
  }

  stateMachine.onTransition(onTransition: printTransition);

  // Define an action predicate for starting vending
  stateMachine.addActionPredicate(
    action: vend,
    onAction: (action) async => action.payload is String,
  );

  // Call an action (this should trigger a transition if the predicate passes)
  await stateMachine.callAction(vend, "to print");

  // Remove the transition listener
  stateMachine.removeListener(printTransition);
}
