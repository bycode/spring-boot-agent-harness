package nl.jinsoo.template.notepad;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import nl.jinsoo.template.TestcontainersConfiguration;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Import;
import org.springframework.modulith.test.ApplicationModuleTest;

@ApplicationModuleTest
@Import(TestcontainersConfiguration.class)
class NotepadModuleTest {

  @Autowired private NotepadAPI notepadAPI;

  @Test
  void createAndFindById() {
    var note = new Note(null, "Module Test", "Testing wiring", null, null);

    var created = notepadAPI.create(note);

    assertThat(created.id()).isNotNull();
    assertThat(created.title()).isEqualTo("Module Test");
    assertThat(created.createdAt()).isNotNull();
    assertThat(created.updatedAt()).isNull();

    var found = notepadAPI.findById(created.id());

    assertThat(found.title()).isEqualTo("Module Test");
  }

  @Test
  void findByIdThrowsWhenNotFound() {
    assertThatThrownBy(() -> notepadAPI.findById(999L)).isInstanceOf(NoteNotFoundException.class);
  }

  @Test
  void listNotesReturnsCreatedNotes() {
    notepadAPI.create(new Note(null, "List Test 1", "Body 1", null, null));
    notepadAPI.create(new Note(null, "List Test 2", "Body 2", null, null));

    var page = notepadAPI.list(0, 100);

    assertThat(page.content()).hasSizeGreaterThanOrEqualTo(2);
    assertThat(page.totalElements()).isGreaterThanOrEqualTo(2);
  }

  @Test
  void updateNote() {
    var created = notepadAPI.create(new Note(null, "Before Update", "Old body", null, null));
    var persisted = notepadAPI.findById(created.id());

    var updated =
        notepadAPI.update(created.id(), new Note(null, "After Update", "New body", null, null));

    assertThat(updated.title()).isEqualTo("After Update");
    assertThat(updated.body()).isEqualTo("New body");
    assertThat(updated.createdAt()).isEqualTo(persisted.createdAt());
    assertThat(updated.updatedAt()).isNotNull();

    var found = notepadAPI.findById(created.id());
    assertThat(found.title()).isEqualTo("After Update");
  }

  @Test
  void updateNonexistentNoteThrows() {
    assertThatThrownBy(() -> notepadAPI.update(999L, new Note(null, "Title", "Body", null, null)))
        .isInstanceOf(NoteNotFoundException.class);
  }

  @Test
  void deleteNote() {
    var created = notepadAPI.create(new Note(null, "To Delete", "Body", null, null));

    notepadAPI.delete(created.id());

    assertThatThrownBy(() -> notepadAPI.findById(created.id()))
        .isInstanceOf(NoteNotFoundException.class);
  }

  @Test
  void deleteNonexistentNoteThrows() {
    assertThatThrownBy(() -> notepadAPI.delete(999L)).isInstanceOf(NoteNotFoundException.class);
  }
}
