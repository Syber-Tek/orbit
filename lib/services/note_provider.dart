import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/models/note.dart';
import 'package:orbit/services/notification_service.dart';
import 'package:orbit/services/persistence_service.dart';

class NoteListNotifier extends Notifier<List<Note>> {
  @override
  List<Note> build() {
    final notes = PersistenceService.instance.loadNotes() ?? const [];
    // Re-arm OS reminders on launch so they survive a force-stop or reboot.
    unawaited(NotificationService.instance.syncNoteReminders(notes));
    return notes;
  }

  void addNote(Note note) {
    state = [note, ...state];
    PersistenceService.instance.saveNotes(state);
    unawaited(NotificationService.instance.scheduleNoteReminder(note));
  }

  void updateNote(Note updated) {
    state = state.map((n) => n.id == updated.id ? updated : n).toList();
    PersistenceService.instance.saveNotes(state);
    unawaited(NotificationService.instance.scheduleNoteReminder(updated));
  }

  void deleteNote(String id) {
    state = state.where((n) => n.id != id).toList();
    PersistenceService.instance.saveNotes(state);
    unawaited(NotificationService.instance.cancelNoteReminder(id));
  }
}

final noteListProvider = NotifierProvider<NoteListNotifier, List<Note>>(
  NoteListNotifier.new,
);

final topNotesProvider = Provider<List<Note>>((ref) {
  final notes = ref.watch(noteListProvider);
  return notes.take(2).toList();
});
