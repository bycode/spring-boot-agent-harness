package nl.jinsoo.template.notepad.internal;

import java.util.Optional;
import nl.jinsoo.template.notepad.Note;
import nl.jinsoo.template.notepad.Page;

public interface NotePersistencePort {

  Note save(Note note);

  Optional<Note> findById(long id);

  Page<Note> findAll(int page, int size);

  boolean deleteById(long id);
}
