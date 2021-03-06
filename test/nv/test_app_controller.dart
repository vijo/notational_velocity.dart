library test.nv.app_controller;

import 'dart:async';
import 'package:unittest/unittest.dart';

import 'package:nv/src/config.dart';
import 'package:nv/src/controllers.dart';
import 'package:nv/src/models.dart';
import 'package:nv/src/shared.dart';
import 'package:nv/src/storage.dart';

const _testTitle1 = 'Test Title 1';

const _V0_NOTE_SERIALIZE = const {
  'version': 0,
  'title': 'v0 note title',
  'lastModified': '2013-09-30 16:42:38.434',
  'content': 'v0 note content'
};

void main(Storage storageFactory()) {
  group('AppController', () {

    _testAppController('simple', storageFactory, _testSimple);

    _testAppController('initial search', storageFactory, _initialSearch);

    _testAppController('legacy note value', () =>
        _customStorageFactory(storageFactory, 4, [_V0_NOTE_SERIALIZE]),
        (AppController ac) {

      expect(ac.runCount, 5);
      expect(ac.notes, hasLength(1));

      expect(ac.notes[0].value.title, _V0_NOTE_SERIALIZE['title']);
      expect(ac.notes[0].value.content, _V0_NOTE_SERIALIZE['content']);
    });

    _testAppController('weird behavior', storageFactory, (AppController ac) {
      ac.resetSearch();

      ac.searchTerm = 'c';

      ac.searchTerm = 'cr';
    });

    _testAppController('select item, edit: sort = stable', storageFactory,
        (AppController ac) {
      _expectFirstRun(ac);

      expect(ac.notes, hasLength(INITIAL_NOTES.length));

      var expectedSortedTitles = INITIAL_NOTES.keys.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      var controllerTitles = ac.notes
          .map((Selectable<Note> s) => s.value.title)
          .toList();

      expect(controllerTitles, orderedEquals(expectedSortedTitles));

      // select the top item
      ac.notes.selectedIndex = 0;

      var content = ac.notes.selectedValue.content;

      var newValue = content + 'v2';

      var updated = ac.updateSelectedNoteContent(newValue);
      expect(updated, isTrue);

      expect(ac.notes.selectedValue.content , newValue);
      expect(ac.notes.selectedIndex, 0);

      return _whenUpdated(ac);
    });

  });
}

Future _initialSearch(AppController ac) {
  expect(ac.notes.hasSelection, isFalse);

  expect(INITIAL_NOTES.keys, contains('About app'));
  expect(INITIAL_NOTES.keys.where((k) => k.toLowerCase().startsWith('about')),
      hasLength(2), reason: 'should have two item that begins w/ "about"');

  var aboutItem = ac.notes.singleWhere((Selectable<NoteViewModel> se) =>
      se.value.title == 'About app');
  var aboutNVItem = ac.notes.singleWhere((Selectable<NoteViewModel> se) =>
      se.value.title == 'About Notational Velocity');

  ac.searchTerm = 'about a';

  return _whenUpdated(ac)
      .then((_) {
        expect(ac.notes, hasLength(1));
        expect(ac.notes[0], same(aboutItem), reason: 'Filtering out items'
          ' should not regenerate items that remain');

        expect(ac.notes.hasSelection, isTrue);

        ac.searchTerm = 'about ';

        return _whenUpdated(ac);
      })
      .then((_) {
        expect(ac.notes, hasLength(2));
        expect(ac.notes.map((s) => s.value),
            orderedEquals([aboutItem, aboutNVItem].map((s) => s.value)));

        ac.searchTerm = 'about n';

        return _whenUpdated(ac);
      })
      .then((_) {
        expect(ac.notes.selectedValue, aboutNVItem.value);
        expect(ac.notes, hasLength(1));
        expect(ac.notes[0].value, aboutNVItem.value);

        ac.searchTerm = 'about ';

        return _whenUpdated(ac);
      })
      .then((_) {

        // Regression test for #36
        expect(ac.notes.hasSelection, isTrue);
        expect(ac.notes.selectedValue, aboutItem.value);
        expect(ac.notes, hasLength(2));
        expect(ac.notes[0].isSelected, isTrue);
        expect(ac.notes[1].isSelected, isFalse);
      });
}

Future _testSimple(AppController controller) {
  _expectFirstRun(controller);

  final tc = 'first content!';

  controller.searchTerm = _testTitle1;

  return _whenUpdated(controller)
      .then((_) {

        expect(controller.notes.hasSelection, isFalse);

        return controller.openOrCreate();
      })
      .then((Note note) {
        expect(note, isNotNull);
        expect(controller.notes.selectedValue, note);

        var nc = note.content;
        expect(nc, isEmpty);

        controller.updateSelectedNoteContent(tc);

        var titleVariations = _permutateTitle(_testTitle1)
          ..add('Test');

        /*

        TODO: need to futz w/ search logic here
        for(var t in titleVariations) {
          model.searchTerm = t;
          var nc = model.openOrCreate();
          expect(nc.title, _testTitle1);
          expect(nc.content, tc);
        }*/

        return _whenUpdated(controller);
      });
}

List<String> _permutateTitle(String title) {
  expect(title, title);
  expect(title.toLowerCase(), isNot(title));
  expect(title.toUpperCase(), isNot(title));
  expect(title.toUpperCase(), isNot(title.toLowerCase()));

  return [title, title.toLowerCase(), title.toUpperCase()];
}

Future<AppController> _whenUpdated(AppController controller) {
  assert(controller != null);
  return Future.wait(controller.notes
      .map((Selectable<NoteViewModel> s) => s.value.whenUpdated))
      .then((_) => controller);
}

Future _expectFirstRun(AppController controller) {
  expect(controller.runCount, 0);
  expect(controller.notes, hasLength(INITIAL_NOTES.length));

  for(Selectable<Note> note in controller.notes) {
    var match = INITIAL_NOTES[note.value.title];
    expect(match, isNotNull);

    expect(note.value.content, match);
  }
}

Future<AppController> _getDebugController(Storage storage) {
  return AppController.init(storage)
    .then(_whenUpdated);
}

Future<Storage> _customStorageFactory(Storage sourceStorageFactory(), int runCount, List<dynamic> initialNoteValues) {
  Storage store;
  return new Future(sourceStorageFactory)
    .then((Storage value) {
      store = value;
      return store.set('runCount', runCount);
    })
    .then((_) {

      var noteStore = new NestedStorage(store, 'notes');

      return Future.forEach(initialNoteValues, (jsonValue) {
        var idString = new KUID.next().toString();

        return noteStore.set(idString, jsonValue);
      });
    })
    .then((_) => store);
}

void _testAppController(String name, dynamic storageFactory(), testFunc(AppController ac)) {
  test(name, () {
    Storage storage;
    return new Future<Storage>.sync(storageFactory)
      .then((Storage value) {
        storage = value;
        return storage;
      })
      .then(_getDebugController)
      .then(testFunc)
      .whenComplete(() {
        if(storage != null) {
          storage.dispose();
        }
      });
  });
}

