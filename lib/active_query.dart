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

library active_query;

import 'dart:async';
import 'dart:html';

Expando<_ObserverRecord> _observers = new Expando<_ObserverRecord>();
Expando<List<ActiveQuery>> _queries = new Expando<List<ActiveQuery>>();

class _ObserverRecord {
  final MutationObserver observer;
  int count = 0;
  _ObserverRecord(this.observer);
}

_addObserver(Node node) {
  var record = _observers[node];
  if (record == null) {
    var observer = new MutationObserver((List<MutationRecord> mutations, var o) {
      for (var mutation in mutations) {
        if (mutation.type == 'attributes') {
          _queries[node].forEach((query) =>
              query._handleChanged(mutation.target));
        } else if (mutation.type == 'childList') {
          if (mutation.addedNodes != null) {
            for (var element in mutation.addedNodes.where((n) => n is Element)) {
              _queries[node].forEach((query) =>
                  query._handleAdded(element));
            }
          }
          if (mutation.removedNodes != null) {
            for (var element in mutation.removedNodes.where((n) => n is Element)) {
              _queries[node].forEach((query) =>
                  query._handleRemoved(element));
            }
          }
        }
      }
    });
    record = _observers[node] = new _ObserverRecord(observer);
    observer.observe(node, attributes: true, childList: true, subtree: true);
  }
  record.count++;
}

_removeObserver(Node node) {
  var record = _observers[node];
  if (record == null) return;
  if (record.count == 1) {
    record.observer.disconnect();
    _observers[node] = null;
  }
  record.count --;
}

/**
 * Creates a new [ActiveQuery] that listens for changes to [node] and provides
 * a [Stream] of [Element]s that newly match [selector], a `Stream` of
 * `Element`s that previously matched `selector`, and a `Stream` of the set of
 * `Element`s that currently match `selector`.
 */
ActiveQuery activeQuery(String selector, {Node node}) {
  node = node == null ? document : node;
  var queries = _queries[node];
  if (queries == null) {
    queries = _queries[node] = <ActiveQuery>[];
  }
  var query = new ActiveQuery(node, selector);
  queries.add(query);
  return query;
}

class ActiveQuery {
  final Node node;
  final String selector;
  // This _shouldn't_ cause a memory leak. When nodes in the set are removed
  // from the DOM, we should be notified and remove them from the set.
  // When the node we're watching contains the reference to this query via
  // the Expando _queries, if no one else is holding a reference to the
  // query, that cycle will be collected.
  final Set<Element> _currentElements = new Set<Element>();

  int _listenerCount = 0;
  StreamController<Element> _added;
  StreamController<Element> _removed;
  StreamController<Set<Element>> _elements;

  ActiveQuery(this.node, this.selector) {
    // TODO: validate selector
    _added = new StreamController<Element>.broadcast(
        onListen: () => _listenerAdded(),
        onCancel: () => _listenerRemoved());
    _removed = new StreamController<Element>.broadcast(
        onListen: () => _listenerAdded(),
        onCancel: () => _listenerRemoved());
    _elements = new StreamController<Set<Element>>.broadcast(
        onListen: () => _listenerAdded(),
        onCancel: () => _listenerRemoved());

    // send all nodes that match through the added stream so that the query can
    // be used for the initial query and subsequent updates.
    // use a microtask so that calling code has a chance to set up listeners
    scheduleMicrotask(() {
      (node as dynamic).querySelectorAll(selector).forEach(_handleAdded);
    });
  }

  void _listenerAdded() {
    if (_listenerCount == 0) {
      _addObserver(node);
    }
    _listenerCount++;
  }

  void _listenerRemoved() {
    if (_listenerCount == 1) {
      _removeObserver(node);
    }
    _listenerCount--;
  }

  /**
   * A [Stream] of [Element]s that match [selector].
   *
   * As elements are added or modified, they are checked against `selector`
   * using [Element.matches]. If the new or modified element matches, it's
   * added to this Stream.
   *
   * When an `ActiveQuery` is first created it also queries [node] with
   * `selector` so that this stream is primed with the set of matching elements
   * even if no mutations occur.
   */
  Stream<Element> get added => _added.stream;

  /**
   * A [Stream] of [Element]s that used to match [selector], but don't after
   * either being removed from the DOM, or by having an attribute changed.
   */
  Stream<Element> get removed => _removed.stream;

  /**
   * The current set of elements that match [selector].
   */
  Stream<Set<Element>> get elements => _elements.stream;

  /**
   * Closes the query and frees resources. This removes the mutation observer
   * if no other query is using the same observer, and closes all streams.
   */
  close() {
    _queries[node].remove(this);
    if (_listenerCount > 0) {
      _removeObserver(node);
    }
    _currentElements.clear();
    _added.close();
    _removed.close();
    _elements.close();
  }

  bool _handleChanged(Element e) {
    // relying on short-circuiting to only call _handleRemoved if e isn't added
    return _handleAdded(e) || _handleRemoved(e);
  }

  bool _handleAdded(Element e) {
    if (!_currentElements.contains(e) && e.matches(selector)) {
      _currentElements.add(e);
      _added.add(e);
      _elements.add(_currentElements);
      return true;
    }
    return false;
  }

  bool _handleRemoved(Element e) {
    if (_currentElements.contains(e) && !e.matches(selector)) {
      _currentElements.remove(e);
      _removed.add(e);
      _elements.add(_currentElements);
      return true;
    }
    return false;
  }
}
