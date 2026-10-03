import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/note.dart';

class NoteListNotifier extends Notifier<List<Note>> {
  @override
  List<Note> build() {
    final now = DateTime.now();

    return [
      Note(
        id: '1',
        title: 'Don\'t forget math homework 📖',
        content: 'Complete calculus chapter 4 problems and review science lab experiment notes before Monday.',
        colorValue: 0xFFE9D8FD, // Soft Lilac
        updatedAt: now.subtract(const Duration(minutes: 45)),
        isPinned: true,
      ),
      Note(
        id: '2',
        title: 'Buy Snacks before 6 PM 🍪',
        content: 'Almond milk, fresh berries, granola, and dark chocolate for focus sessions.',
        colorValue: 0xFFDCEBFE, // Soft Sky Blue
        updatedAt: now.subtract(const Duration(hours: 3)),
        isPinned: true,
      ),
      Note(
        id: '3',
        title: 'Water the plants 🪴',
        content: 'Mist the monstera leaves and soak the bonsai plant.',
        colorValue: 0xFFD1FAE5, // Soft Mint
        updatedAt: now.subtract(const Duration(days: 1)),
      ),
      Note(
        id: '4',
        title: 'Weekly Orbit Review 🚀',
        content: 'Reflect on habits completion, budget spending, and screen time trends.',
        colorValue: 0xFFFFEDD5, // Soft Peach
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
    ];
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
