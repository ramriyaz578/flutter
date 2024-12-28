// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:test/test.dart';

final List<String> results = <String>[];

Set<TestRoute> routes = new Set<TestRoute>();

class TestRoute extends Route<String> {
  TestRoute(this.name);
  final String name;

  List<OverlayEntry> get overlayEntries => _entries;

  List<OverlayEntry> _entries = <OverlayEntry>[];

  void log(String s) {
    results.add('$name: $s');
  }

  void install(OverlayEntry insertionPoint) {
    log('install');
    OverlayEntry entry = new OverlayEntry(
      builder: (BuildContext context) => new Container(),
      opaque: true
    );
    _entries.add(entry);
    navigator.overlay?.insert(entry, above: insertionPoint);
    routes.add(this);
  }

  void didPush() {
    log('didPush');
  }

  void didReplace(TestRoute oldRoute) {
    log('didReplace ${oldRoute.name}');
  }

  bool didPop(String result) {
    log('didPop $result');
    bool returnValue;
    if (returnValue = super.didPop(result))
      dispose();
    return returnValue;
  }

  void didPushNext(TestRoute nextRoute) {
    log('didPushNext ${nextRoute.name}');
  }

  void didPopNext(TestRoute nextRoute) {
    log('didPopNext ${nextRoute.name}');
  }

  void didReplaceNext(TestRoute oldNextRoute, TestRoute newNextRoute) {
    log('didReplaceNext ${oldNextRoute.name} ${newNextRoute.name}');
  }

  void dispose() {
    log('dispose');
    _entries.forEach((OverlayEntry entry) { entry.remove(); });
    _entries.clear();
    routes.remove(this);
  }

}

void runNavigatorTest(
  WidgetTester tester,
  NavigatorState host,
  NavigatorTransactionCallback test,
  List<String> expectations
) {
  expect(host, isNotNull);
  host.openTransaction(test);
  expect(results, equals(expectations));
  results.clear();
  tester.pump();
}

void main() {
  test('Route management - push, replace, pop', () {
    testWidgets((WidgetTester tester) {
      GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();
      tester.pumpWidget(new Navigator(
        key: navigatorKey,
        onGenerateRoute: (_) => new TestRoute('initial')
      ));
      NavigatorState host = navigatorKey.currentState;
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
        },
        [
          'initial: install',
          'initial: didPush',
        ]
      );
      TestRoute second;
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.push(second = new TestRoute('second'));
        },
        [
          'second: install',
          'second: didPush',
          'initial: didPushNext second',
        ]
      );
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.push(new TestRoute('third'));
        },
        [
          'third: install',
          'third: didPush',
          'second: didPushNext third',
        ]
      );
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.replace(oldRoute: second, newRoute: new TestRoute('two'));
        },
        [
          'two: install',
          'two: didReplace second',
          'initial: didReplaceNext second two',
          'second: dispose',
        ]
      );
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.pop('hello');
        },
        [
          'third: didPop hello',
          'third: dispose',
          'two: didPopNext third',
        ]
      );
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.pop('good bye');
        },
        [
          'two: didPop good bye',
          'two: dispose',
          'initial: didPopNext two',
        ]
      );
      tester.pumpWidget(new Container());
      expect(results, equals(['initial: dispose']));
      expect(routes.isEmpty, isTrue);
      results.clear();
    });
  });

  test('Route management - push, remove, pop', () {
    testWidgets((WidgetTester tester) {
      GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();
      tester.pumpWidget(new Navigator(
        key: navigatorKey,
        onGenerateRoute: (_) => new TestRoute('first')
      ));
      NavigatorState host = navigatorKey.currentState;
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
        },
        [
          'first: install',
          'first: didPush',
        ]
      );
      TestRoute second;
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.push(second = new TestRoute('second'));
        },
        [
          'second: install',
          'second: didPush',
          'first: didPushNext second',
        ]
      );
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.push(new TestRoute('third'));
        },
        [
          'third: install',
          'third: didPush',
          'second: didPushNext third',
        ]
      );
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.removeRouteBefore(second);
        },
        [
          'first: dispose',
        ]
      );
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.pop('good bye');
        },
        [
          'third: didPop good bye',
          'third: dispose',
          'second: didPopNext third',
        ]
      );
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.push(new TestRoute('three'));
        },
        [
          'three: install',
          'three: didPush',
          'second: didPushNext three',
        ]
      );
      TestRoute four;
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.push(four = new TestRoute('four'));
        },
        [
          'four: install',
          'four: didPush',
          'three: didPushNext four',
        ]
      );
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.removeRouteBefore(four);
        },
        [
          'three: dispose',
        ]
      );
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.pop('the end');
        },
        [
          'four: didPop the end',
          'four: dispose',
          'second: didPopNext four',
        ]
      );
      tester.pumpWidget(new Container());
      expect(results, equals(['second: dispose']));
      expect(routes.isEmpty, isTrue);
      results.clear();
    });
  });

  test('Route management - push, replace, popUntil', () {
    testWidgets((WidgetTester tester) {
      GlobalKey<NavigatorState> navigatorKey = new GlobalKey<NavigatorState>();
      tester.pumpWidget(new Navigator(
        key: navigatorKey,
        onGenerateRoute: (_) => new TestRoute('A')
      ));
      NavigatorState host = navigatorKey.currentState;
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
        },
        [
          'A: install',
          'A: didPush',
        ]
      );
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.push(new TestRoute('B'));
        },
        [
          'B: install',
          'B: didPush',
          'A: didPushNext B',
        ]
      );
      TestRoute routeC;
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.push(routeC = new TestRoute('C'));
        },
        [
          'C: install',
          'C: didPush',
          'B: didPushNext C',
        ]
      );
      TestRoute routeB;
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.replaceRouteBefore(anchorRoute: routeC, newRoute: routeB = new TestRoute('b'));
        },
        [
          'b: install',
          'b: didReplace B',
          'A: didReplaceNext B b',
          'B: dispose',
        ]
      );
      runNavigatorTest(
        tester,
        host,
        (NavigatorTransaction transaction) {
          transaction.popUntil(routeB);
        },
        [
          'C: didPop null',
          'C: dispose',
          'b: didPopNext C',
        ]
      );
      tester.pumpWidget(new Container());
      expect(results, equals(['A: dispose', 'b: dispose']));
      expect(routes.isEmpty, isTrue);
      results.clear();
    });
  });
}
