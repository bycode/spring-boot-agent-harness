package nl.jinsoo.template.notepad.internal;

import lombok.extern.slf4j.Slf4j;
import nl.jinsoo.template.notepad.Note;
import nl.jinsoo.template.notepad.NotepadAPI;
import nl.jinsoo.template.notepad.Page;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
class NotepadFacade implements NotepadAPI {

  private final CreateNoteUseCase createNote;
  private final FindNoteByIdUseCase findNote;
  private final ListNotesUseCase listNotes;
  private final UpdateNoteUseCase updateNote;
  private final DeleteNoteUseCase deleteNote;

  NotepadFacade(
      CreateNoteUseCase createNote,
      FindNoteByIdUseCase findNote,
      ListNotesUseCase listNotes,
      UpdateNoteUseCase updateNote,
      DeleteNoteUseCase deleteNote) {
    this.createNote = createNote;
    this.findNote = findNote;
    this.listNotes = listNotes;
    this.updateNote = updateNote;
    this.deleteNote = deleteNote;
  }

  @Override
  @Transactional
  public Note create(Note note) {
    log.info("[NotepadFacade.create] Creating note title={}", note.title());
    var result = createNote.execute(note);
    log.info("[NotepadFacade.create] Created note id={}", result.id());
    return result;
  }

  @Override
  @Transactional(readOnly = true)
  public Note findById(long id) {
    log.info("[NotepadFacade.findById] Finding note id={}", id);
    return findNote.execute(id);
  }

  @Override
  @Transactional(readOnly = true)
  public Page<Note> list(int page, int size) {
    log.info("[NotepadFacade.list] Listing notes page={} size={}", page, size);
    return listNotes.execute(page, size);
  }

  @Override
  @Transactional
  public Note update(long id, Note note) {
    log.info("[NotepadFacade.update] Updating note id={}", id);
    var result = updateNote.execute(id, note);
    log.info("[NotepadFacade.update] Updated note id={}", result.id());
    return result;
  }

  @Override
  @Transactional
  public void delete(long id) {
    log.info("[NotepadFacade.delete] Deleting note id={}", id);
    deleteNote.execute(id);
    log.info("[NotepadFacade.delete] Deleted note id={}", id);
  }
}
