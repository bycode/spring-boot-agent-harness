package nl.jinsoo.template.notepad.internal;

import nl.jinsoo.template.notepad.NotepadAPI;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration(proxyBeanMethods = false)
class NotepadModuleConfiguration {

  @Bean
  NotepadAPI notepadAPI(NotePersistencePort persistence) {
    var createNote = new CreateNoteUseCase(persistence);
    var findNote = new FindNoteByIdUseCase(persistence);
    var listNotes = new ListNotesUseCase(persistence);
    var updateNote = new UpdateNoteUseCase(persistence);
    var deleteNote = new DeleteNoteUseCase(persistence);
    return new NotepadFacade(createNote, findNote, listNotes, updateNote, deleteNote);
  }
}
