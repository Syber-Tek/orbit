import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/note.dart';
import 'package:orbit/services/persistence_service.dart';

class NoteListNotifier extends Notifier<List<Note>> {
  @override
  List<Note> build() {
    return PersistenceService.instance.loadNotes() ?? const [];
  }

  void addNote(Note note) {
    state = [note, ...state];
    PersistenceService.instance.saveNotes(state);
  }

  void updateNote(Note updated) {
    state = state.map((n) => n.id == updated.id ? updated : n).toList();
    PersistenceService.instance.saveNotes(state);
  }

  void deleteNote(String id) {
    state = state.where((n) => n.id != id).toList();
    PersistenceService.instance.saveNotes(state);
  }
}

final noteListProvider = NotifierProvider<NoteListNotifier, List<Note>>(
  NoteListNotifier.new,
);

final topNotesProvider = Provider<List<Note>>((ref) {
  final notes = ref.watch(noteListProvider);
  return notes.take(2).toList();
});
