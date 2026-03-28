package nl.jinsoo.template.notepad.rest;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.Instant;
import nl.jinsoo.template.notepad.Note;
import org.jspecify.annotations.Nullable;

@Schema(description = "Note response")
record NoteResponseDTO(
    @Schema(description = "Note ID") long id,
    @Schema(description = "Note title") String title,
    @Schema(description = "Note body") String body,
    @Schema(description = "Creation timestamp") Instant createdAt,
    @Schema(description = "Last update timestamp") @Nullable Instant updatedAt) {

  static NoteResponseDTO from(Note note) {
    return new NoteResponseDTO(
        note.id(), note.title(), note.body(), note.createdAt(), note.updatedAt());
  }
}
