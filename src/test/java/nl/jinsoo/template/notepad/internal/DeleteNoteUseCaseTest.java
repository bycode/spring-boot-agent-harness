package nl.jinsoo.template.notepad.internal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;
import nl.jinsoo.template.notepad.Note;
import nl.jinsoo.template.notepad.NoteNotFoundException;
import org.junit.jupiter.api.Test;

class DeleteNoteUseCaseTest {

  private final InMemoryNotePersistence persistence = new InMemoryNotePersistence();
  private final DeleteNoteUseCase useCase = new DeleteNoteUseCase(persistence);

  @Test
  void deletesExistingNote() {
    var saved = persistence.save(new Note(null, "Title", "Body", Instant.now(), null));

    useCase.execute(saved.id());

    assertThat(persistence.findById(saved.id())).isEmpty();
  }

  @Test
  void throwsWhenNoteNotFound() {
    assertThatThrownBy(() -> useCase.execute(999L))
        .isInstanceOf(NoteNotFoundException.class)
        .hasMessageContaining("999");
  }
}
