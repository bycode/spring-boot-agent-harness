package nl.jinsoo.template.notepad.rest;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;
import nl.jinsoo.template.notepad.Note;
import nl.jinsoo.template.notepad.Page;

@Schema(description = "Paginated list of notes")
record NotePageResponseDTO(
    @Schema(description = "List of notes") List<NoteResponseDTO> content,
    @Schema(description = "Current page number (0-based)") int page,
    @Schema(description = "Page size") int size,
    @Schema(description = "Total number of notes") long totalElements,
    @Schema(description = "Total number of pages") int totalPages) {

  static NotePageResponseDTO from(Page<Note> notePage) {
    var content = notePage.content().stream().map(NoteResponseDTO::from).toList();
    return new NotePageResponseDTO(
        content, notePage.page(), notePage.size(), notePage.totalElements(), notePage.totalPages());
  }
}
