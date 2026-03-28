package nl.jinsoo.template.notepad.internal;

import java.time.Instant;
import nl.jinsoo.template.notepad.Note;

class CreateNoteUseCase {

  private final NotePersistencePort persistence;

  CreateNoteUseCase(NotePersistencePort persistence) {
    this.persistence = persistence;
  }

  Note execute(Note note) {
    var noteToSave = new Note(null, note.title(), note.body(), Instant.now(), null);
    return persistence.save(noteToSave);
  }
}
