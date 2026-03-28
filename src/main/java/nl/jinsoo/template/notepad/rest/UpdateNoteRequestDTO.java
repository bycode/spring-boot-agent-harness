package nl.jinsoo.template.notepad.rest;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import nl.jinsoo.template.notepad.Note;

@Schema(description = "Request to update a note")
record UpdateNoteRequestDTO(
    @NotBlank @Size(max = 200) @Schema(description = "Note title", example = "Updated title")
        String title,
    @NotBlank @Size(max = 10_000) @Schema(description = "Note body", example = "Updated body")
        String body) {

  Note toDomain() {
    return new Note(null, title, body, null, null);
  }
}
