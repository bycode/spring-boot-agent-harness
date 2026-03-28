package nl.jinsoo.template.notepad;

public interface NotepadAPI {

  Note create(Note note);

  Note findById(long id);

  Page<Note> list(int page, int size);

  Note update(long id, Note note);

  void delete(long id);
}
