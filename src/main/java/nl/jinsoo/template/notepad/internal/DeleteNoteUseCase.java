package nl.jinsoo.template.notepad.internal;

import nl.jinsoo.template.notepad.NoteNotFoundException;

class DeleteNoteUseCase {

  private final NotePersistencePort persistence;

  DeleteNoteUseCase(NotePersistencePort persistence) {
    this.persistence = persistence;
  }

  void execute(long id) {
    if (!persistence.deleteById(id)) {
      throw new NoteNotFoundException(id);
    }
  }
}
