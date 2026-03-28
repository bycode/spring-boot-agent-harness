package nl.jinsoo.template.notepad.internal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;
import nl.jinsoo.template.notepad.Note;
import nl.jinsoo.template.notepad.NoteNotFoundException;
import org.junit.jupiter.api.Test;

class UpdateNoteUseCaseTest {

  private final InMemoryNotePersistence persistence = new InMemoryNotePersistence();
  private final UpdateNoteUseCase useCase = new UpdateNoteUseCase(persistence);

  @Test
  void updatesFieldsAndSetsUpdatedAt() {
    var createdAt = Instant.parse("2026-01-01T00:00:00Z");
    var saved = persistence.save(new Note(null, "Original", "Original body", createdAt, null));

    var input = new Note(null, "Updated", "Updated body", null, null);
    var result = useCase.execute(saved.id(), input);

    assertThat(result.id()).isEqualTo(saved.id());
    assertThat(result.title()).isEqualTo("Updated");
    assertThat(result.body()).isEqualTo("Updated body");
    assertThat(result.createdAt()).isEqualTo(createdAt);
    assertThat(result.updatedAt()).isNotNull();
  }

  @Test
  void throwsWhenNoteNotFound() {
    var input = new Note(null, "Title", "Body", null, null);

    assertThatThrownBy(() -> useCase.execute(999L, input))
        .isInstanceOf(NoteNotFoundException.class)
        .hasMessageContaining("999");
  }
}
