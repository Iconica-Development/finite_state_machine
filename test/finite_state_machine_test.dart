import "dart:async";

import "package:finite_state_machine/finite_state_machine.dart";
import "package:test/test.dart";

void main() {
  group("Finite State Machine", () {
    late FiniteStateMachine sut;
    late FSMState locked;
    late FSMState open;

    late FSMAction openWithKey;
    late FSMAction lockWithKey;
    late FSMAction lookInside;
    late FSMAction placeItem;

    late FSMTransition locking;
    late FSMTransition unlocking;

    setUp(() {
      sut = FiniteStateMachine();
      locked = sut.addState("locked");
      open = sut.addState("open");

      locking = FSMTransition(name: "locking", targetState: locked);
      unlocking = FSMTransition(name: "unlocking", targetState: open);

      openWithKey = FSMAction(name: "open with key", transition: unlocking);
      lockWithKey = FSMAction(name: "lock with key", transition: locking);
      lookInside = FSMAction(name: "look inside");
      placeItem = FSMAction(name: "place item");

      sut.addAction([locked], openWithKey);
      sut.addAction([open], lockWithKey);
      sut.addAction([open], lookInside);
      sut.addAction([open], placeItem);

      sut.start(locked);
    });

    test("should allow for a normal transition", () async {
      await sut.callAction(openWithKey);
      expect(sut.current, equals(open));
      await sut.callAction(lockWithKey);
      expect(sut.current, equals(locked));
    });

    test(
      "Should throw an error if an action is called in an illegal state",
      () async {
        expect(() async {
          await sut.callAction(lookInside);
        }, throwsA(isA<FSMIllegalActionException>()));
      },
    );

    test("Should listen to transitions properly", () async {
      var streamController = StreamController<FSMTransitionExecution>();
      sut.onExitState(
        onExitState: (transition) {
          streamController.add(transition);
        },
      );
      await sut.callAction(openWithKey);
      await sut.callAction(lockWithKey);

      expect(
        streamController.stream,
        emitsInOrder([
          predicate<FSMTransitionExecution>(
            (value) =>
                value.action == openWithKey &&
                value.to == openWithKey.transition?.targetState,
          ),
          predicate<FSMTransitionExecution>(
            (value) =>
                value.action == lockWithKey &&
                value.to == lockWithKey.transition?.targetState,
          ),
        ]),
      );

      await streamController.close();
    });

    test("Should listen to states properly", () async {
      var streamController = StreamController<FSMState>();
      sut.onStateChanged((state) {
        streamController.add(state);
      });
      await sut.callAction(openWithKey);
      await sut.callAction(lockWithKey);

      expect(
        streamController.stream,
        emitsInOrder([equals(open), equals(locked)]),
      );

      await streamController.close();
    });

    tearDown(() {
      sut.dispose();
    });
  });
}
