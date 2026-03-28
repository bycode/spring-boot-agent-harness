package nl.jinsoo.template.notepad.internal;

import java.time.Instant;
import nl.jinsoo.template.notepad.Note;
import nl.jinsoo.template.notepad.NoteNotFoundException;

class UpdateNoteUseCase {

  private final NotePersistencePort persistence;

  UpdateNoteUseCase(NotePersistencePort persistence) {
    this.persistence = persistence;
  }

  Note execute(long id, Note note) {
    var existing = persistence.findById(id).orElseThrow(() -> new NoteNotFoundException(id));
    var updated =
        new Note(existing.id(), note.title(), note.body(), existing.createdAt(), Instant.now());
    return persistence.save(updated);
  }
}
