import 'dart:async';
import 'dart:html';
import 'package:active_query/active_query.dart';

main() {
  activeQuery('[important]')
    ..added.listen((element) {
      print("${element.classes.first} is now important");
    })
    ..removed.listen((element) {
      print("${element.classes.first} is no longer important");
    })
    ..elements.listen((elements) {
      print("Important elements: ${elements.map((e) => e.classes.first)}");
    });

  // We need to perform each mutation in a Future so that the browser doesn't
  // coalesce them and not trigger our observer.
  new Future(() {
    print("first mutation");
    querySelector('div.two').attributes['important'] = '';
  }).then((_) => new Future(() {
    print("second mutation");
    querySelector('div.one').attributes.remove('important');
  })).then((_) => new Future(() {
    print("third mutation");
    querySelector('div.two').attributes.remove('important');
  }));
}
