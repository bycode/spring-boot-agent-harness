package nl.jinsoo.template.notepad.rest;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Instant;
import java.util.List;
import nl.jinsoo.template.SecurityConfig;
import nl.jinsoo.template.notepad.Note;
import nl.jinsoo.template.notepad.NoteNotFoundException;
import nl.jinsoo.template.notepad.NotepadAPI;
import nl.jinsoo.template.notepad.Page;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

@WebMvcTest(NoteController.class)
@Import(SecurityConfig.class)
@TestPropertySource(
    properties = "jwt.secret-key=test-key-must-be-at-least-256-bits-for-hmac-sha256")
@WithMockUser
class NoteControllerSliceTest {

  @Autowired MockMvcTester mvc;
  @MockitoBean NotepadAPI notepadAPI;

  private static final Instant NOW = Instant.parse("2026-01-01T00:00:00Z");

  @Test
  void createReturns201WithResponseBody() {
    var note = new Note(1L, "Title", "Body", NOW, null);
    Mockito.when(notepadAPI.create(Mockito.any())).thenReturn(note);

    assertThat(
            mvc.post()
                .uri("/api/notes")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"title": "Title", "body": "Body"}
                    """))
        .hasStatus(201)
        .bodyJson()
        .extractingPath("$.title")
        .isEqualTo("Title");
  }

  @Test
  void findByIdReturns200WithNote() {
    var note = new Note(1L, "Title", "Body", NOW, null);
    Mockito.when(notepadAPI.findById(1L)).thenReturn(note);

    assertThat(mvc.get().uri("/api/notes/1"))
        .hasStatus(200)
        .bodyJson()
        .extractingPath("$.id")
        .isEqualTo(1);
  }

  @Test
  void findByIdReturns404WhenNotFound() {
    Mockito.when(notepadAPI.findById(999L)).thenThrow(new NoteNotFoundException(999L));

    assertThat(mvc.get().uri("/api/notes/999")).hasStatus(404);
  }

  @Test
  void createReturns400WhenTitleBlank() {
    assertThat(
            mvc.post()
                .uri("/api/notes")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"title": "", "body": "Body"}
                    """))
        .hasStatus(400);
  }

  @Test
  void listReturns200WithPagedResults() {
    var notes = List.of(new Note(1L, "First", "Body 1", NOW, null));
    var page = new Page<>(notes, 0, 20, 1, 1);
    Mockito.when(notepadAPI.list(0, 20)).thenReturn(page);

    assertThat(mvc.get().uri("/api/notes?page=0&size=20"))
        .hasStatus(200)
        .bodyJson()
        .extractingPath("$.content")
        .asList()
        .hasSize(1);
  }

  @Test
  void updateReturns200WithUpdatedNote() {
    var note = new Note(1L, "Updated", "Updated body", NOW, NOW.plusSeconds(60));
    Mockito.when(notepadAPI.update(Mockito.eq(1L), Mockito.any())).thenReturn(note);

    assertThat(
            mvc.put()
                .uri("/api/notes/1")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"title": "Updated", "body": "Updated body"}
                    """))
        .hasStatus(200)
        .bodyJson()
        .extractingPath("$.title")
        .isEqualTo("Updated");
  }

  @Test
  void updateReturns404WhenNotFound() {
    Mockito.when(notepadAPI.update(Mockito.eq(999L), Mockito.any()))
        .thenThrow(new NoteNotFoundException(999L));

    assertThat(
            mvc.put()
                .uri("/api/notes/999")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"title": "Title", "body": "Body"}
                    """))
        .hasStatus(404);
  }

  @Test
  void updateReturns400WhenTitleBlank() {
    assertThat(
            mvc.put()
                .uri("/api/notes/1")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """
                    {"title": "", "body": "Body"}
                    """))
        .hasStatus(400);
  }

  @Test
  void deleteReturns204() {
    assertThat(mvc.delete().uri("/api/notes/1")).hasStatus(204);
    Mockito.verify(notepadAPI).delete(1L);
  }

  @Test
  void deleteReturns404WhenNotFound() {
    Mockito.doThrow(new NoteNotFoundException(999L)).when(notepadAPI).delete(999L);

    assertThat(mvc.delete().uri("/api/notes/999")).hasStatus(404);
  }

  @Test
  void listReturns400WhenPageIsNegative() {
    assertThat(mvc.get().uri("/api/notes?page=-1&size=20")).hasStatus(400);
  }

  @Test
  void listReturns400WhenSizeIsZero() {
    assertThat(mvc.get().uri("/api/notes?page=0&size=0")).hasStatus(400);
  }

  @Test
  void listReturns400WhenSizeExceedsMax() {
    assertThat(mvc.get().uri("/api/notes?page=0&size=101")).hasStatus(400);
  }
}
