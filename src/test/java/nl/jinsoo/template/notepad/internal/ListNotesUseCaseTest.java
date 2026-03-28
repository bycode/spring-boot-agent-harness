package nl.jinsoo.template.notepad.internal;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import nl.jinsoo.template.notepad.Note;
import org.junit.jupiter.api.Test;

class ListNotesUseCaseTest {

  private final InMemoryNotePersistence persistence = new InMemoryNotePersistence();
  private final ListNotesUseCase useCase = new ListNotesUseCase(persistence);

  @Test
  void returnsEmptyPageWhenNoNotes() {
    var result = useCase.execute(0, 20);

    assertThat(result.content()).isEmpty();
    assertThat(result.totalElements()).isZero();
    assertThat(result.totalPages()).isZero();
  }

  @Test
  void returnsPaginatedResults() {
    var now = Instant.now();
    persistence.save(new Note(null, "First", "Body 1", now.minusSeconds(2), null));
    persistence.save(new Note(null, "Second", "Body 2", now.minusSeconds(1), null));
    persistence.save(new Note(null, "Third", "Body 3", now, null));

    var page0 = useCase.execute(0, 2);

    assertThat(page0.content()).hasSize(2);
    assertThat(page0.page()).isZero();
    assertThat(page0.size()).isEqualTo(2);
    assertThat(page0.totalElements()).isEqualTo(3);
    assertThat(page0.totalPages()).isEqualTo(2);

    var page1 = useCase.execute(1, 2);

    assertThat(page1.content()).hasSize(1);
    assertThat(page1.page()).isEqualTo(1);
  }
}
