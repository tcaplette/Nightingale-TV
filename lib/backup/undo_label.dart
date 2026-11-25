import '../l10n/tr.dart';

// No dart:io here: the web admin shows the same label (backup-simplify D9).

/// The undo point's button for a backup saved for [reason] ("before-reset"
/// and the like) about [subject] (a deleted profile's name): "Undo lineup
/// reset", "Undo deleting Kids"…
String undoLabel(String reason, String? subject) => switch (reason) {
      'before-reset' => tr.undoLineupReset,
      'before-delete' => subject == null ? tr.undoDeletingAProfile : tr.undoDeleting(subject),
      'before-upgrade' => tr.undoUpdate,
      'before-lineup-cleanup' => tr.undoLineupCleanup,
      _ => tr.undoRestore,
    };
