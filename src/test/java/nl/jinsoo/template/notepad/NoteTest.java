package nl.jinsoo.template.notepad;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import org.junit.jupiter.api.Test;

class NoteTest {

  @Test
  void recordFieldsAreAccessible() {
    var now = Instant.now();
    var note = new Note(1L, "Title", "Body", now, now);

    assertThat(note.id()).isEqualTo(1L);
    assertThat(note.title()).isEqualTo("Title");
    assertThat(note.body()).isEqualTo("Body");
    assertThat(note.createdAt()).isEqualTo(now);
    assertThat(note.updatedAt()).isEqualTo(now);
  }

  @Test
  void nullIdRepresentsNewNote() {
    var note = new Note(null, "Title", "Body", Instant.now(), null);
    assertThat(note.id()).isNull();
  }

  @Test
  void updatedAtIsNullForNewNotes() {
    var note = new Note(1L, "Title", "Body", Instant.now(), null);
    assertThat(note.updatedAt()).isNull();
  }
}
