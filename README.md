<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages). 
-->

This package contains the finite state machine for veromatic.

## Features

A simple state machine that allows you to switch between states through the actions provided.

The user can also listen to the changes through the leave, enter and transition listeners.

State transitions can be cancelled by attaching a cancelIf to an action.

## Getting started

Simply add this package to your project, then create the VeromaticStateMachine.

This will give you a fully configured finite state machine, which is started at the initializing state.

Then simply call any allowed action and the state machine will transform to the corresponding state.

## Usage

```dart
// Creates a state machine
var fsm = FiniteStateMachine();

var initialize = fsm.addState("initialize");

// subscribes to a transition
var transitionSubscription = fsm.onTransition.listen((transition) {
  stdout.writeln(transition);
});

// changes to the not ready state by calling initialize
fsm.callAction(fsm);

// Create an asynchronous gap so that the listeners can run
await Future.delayed(Duration.zero);

// Make sure to dispose your subscription 
await transitionSubscription.cancel();
```