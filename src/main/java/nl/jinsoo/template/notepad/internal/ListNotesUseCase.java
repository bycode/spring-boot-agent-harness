package nl.jinsoo.template.notepad.internal;

import nl.jinsoo.template.notepad.Note;
import nl.jinsoo.template.notepad.Page;

class ListNotesUseCase {

  private final NotePersistencePort persistence;

  ListNotesUseCase(NotePersistencePort persistence) {
    this.persistence = persistence;
  }

  Page<Note> execute(int page, int size) {
    return persistence.findAll(page, size);
  }
}
