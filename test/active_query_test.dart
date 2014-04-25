// Copyright 2014 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

library epoxy.active_query_test;

import 'dart:async';
import 'dart:html';

import 'package:active_query/active_query.dart';
import 'package:unittest/unittest.dart';
import 'package:unittest/html_enhanced_config.dart'
    show useHtmlEnhancedConfiguration;

main() {

  useHtmlEnhancedConfiguration();

  var timeout = new Duration(seconds: 1);

  group('activeQuery', () {
    var testDiv = querySelector('#test-div');

    setUp(() {
      testDiv.children.clear();
    });

    test('should send an event when an element matches a query', () {
      var query = activeQuery('.foo');
      var addThis = new DivElement()..classes.add('foo');
      testDiv.children.add(addThis);
      return query.added.first.then((el) {
        expect(el, addThis);
      }).timeout(timeout);
    });

    test('should not send an event when an element does not match a query', () {
      var query = activeQuery('.foo');
      var addThis = new DivElement()..classes.add('bar');
      query.added.listen((el) {
        fail('should not have received an event: $el');
      });
      testDiv.children.add(addThis);
      return new Future(() {
        query.close();
      });
    });

    test('should send an event when an element used to match a query', () {
      var addThis = new DivElement()..classes.add('foo');
      testDiv.children.add(addThis);
      var query = activeQuery('.foo');
      var future = query.removed.first.then((el) {
        expect(el, addThis);
      });
      new Future(() {
        addThis.classes.remove('foo');
      });
      return future.timeout(timeout).then((_) {
        query.close();
      });
    });

  });

}