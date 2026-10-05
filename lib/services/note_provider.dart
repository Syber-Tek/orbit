import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/note.dart';

class NoteListNotifier extends Notifier<List<Note>> {
  @override
  List<Note> build() {
    return const [];
  }

  void addNote(Note note) {
    state = [note, ...state];
  }

  void updateNote(Note updated) {
    state = state.map((n) => n.id == updated.id ? updated : n).toList();
  }

  void deleteNote(String id) {
    state = state.where((n) => n.id != id).toList();
  }
}

final noteListProvider = NotifierProvider<NoteListNotifier, List<Note>>(
  NoteListNotifier.new,
);

final topNotesProvider = Provider<List<Note>>((ref) {
  final notes = ref.watch(noteListProvider);
  return notes.take(2).toList();
});
