package nl.jinsoo.template.notepad.internal;

import static org.assertj.core.api.Assertions.assertThat;

import nl.jinsoo.template.notepad.Note;
import org.junit.jupiter.api.Test;

class CreateNoteUseCaseTest {

  private final InMemoryNotePersistence persistence = new InMemoryNotePersistence();
  private final CreateNoteUseCase useCase = new CreateNoteUseCase(persistence);

  @Test
  void setsCreatedAtAndDelegatesToPort() {
    var input = new Note(null, "Title", "Body", null, null);

    var result = useCase.execute(input);

    assertThat(result.id()).isNotNull();
    assertThat(result.title()).isEqualTo("Title");
    assertThat(result.body()).isEqualTo("Body");
    assertThat(result.createdAt()).isNotNull();
    assertThat(result.updatedAt()).isNull();
  }

  @Test
  void assignsNullIdBeforeSaving() {
    var input = new Note(99L, "Title", "Body", null, null);

    var result = useCase.execute(input);

    assertThat(result.title()).isEqualTo("Title");
    assertThat(result.createdAt()).isNotNull();
  }
}
