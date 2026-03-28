package nl.jinsoo.template.notepad.persistence;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import nl.jinsoo.template.TestcontainersConfiguration;
import nl.jinsoo.template.notepad.Note;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jdbc.test.autoconfigure.DataJdbcTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.context.annotation.Import;

@DataJdbcTest
@Import({NoteRepositoryAdapter.class, TestcontainersConfiguration.class})
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
class NoteRepositoryAdapterTest {

  @Autowired private NoteRepositoryAdapter adapter;

  @Test
  void saveAndFindRoundTrip() {
    var note = new Note(null, "Test Title", "Test Body", Instant.now(), null);

    var saved = adapter.save(note);

    assertThat(saved.id()).isNotNull();
    assertThat(saved.title()).isEqualTo("Test Title");
    assertThat(saved.body()).isEqualTo("Test Body");
    assertThat(saved.createdAt()).isNotNull();
    assertThat(saved.updatedAt()).isNull();

    var found = adapter.findById(saved.id());

    assertThat(found).isPresent();
    assertThat(found.get().title()).isEqualTo("Test Title");
  }

  @Test
  void findByIdReturnsEmptyForNonexistent() {
    var result = adapter.findById(999L);
    assertThat(result).isEmpty();
  }

  @Test
  void findAllReturnsPaginatedResults() {
    adapter.save(new Note(null, "Note 1", "Body 1", Instant.now().minusSeconds(2), null));
    adapter.save(new Note(null, "Note 2", "Body 2", Instant.now().minusSeconds(1), null));
    adapter.save(new Note(null, "Note 3", "Body 3", Instant.now(), null));

    var page = adapter.findAll(0, 2);

    assertThat(page.content()).hasSize(2);
    assertThat(page.totalElements()).isEqualTo(3);
    assertThat(page.totalPages()).isEqualTo(2);
    assertThat(page.page()).isZero();
  }

  @Test
  void deleteByIdReturnsTrueAndRemovesNote() {
    var saved = adapter.save(new Note(null, "Title", "Body", Instant.now(), null));

    assertThat(adapter.deleteById(saved.id())).isTrue();
    assertThat(adapter.findById(saved.id())).isEmpty();
  }

  @Test
  void deleteByIdReturnsFalseForNonexistent() {
    assertThat(adapter.deleteById(999L)).isFalse();
  }

  @Test
  void saveUpdatesExistingNote() {
    var saved = adapter.save(new Note(null, "Original", "Original body", Instant.now(), null));

    var updated = new Note(saved.id(), "Updated", "Updated body", saved.createdAt(), Instant.now());
    var result = adapter.save(updated);

    assertThat(result.id()).isEqualTo(saved.id());
    assertThat(result.title()).isEqualTo("Updated");
    assertThat(result.body()).isEqualTo("Updated body");
    assertThat(result.updatedAt()).isNotNull();
  }
}
