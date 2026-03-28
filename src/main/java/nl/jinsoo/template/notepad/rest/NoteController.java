package nl.jinsoo.template.notepad.rest;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import nl.jinsoo.template.notepad.NotepadAPI;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/notes")
@Tag(name = "Notepad", description = "Reference implementation — delete when starting real work")
class NoteController {

  private final NotepadAPI notepadAPI;

  NoteController(NotepadAPI notepadAPI) {
    this.notepadAPI = notepadAPI;
  }

  @PostMapping
  @Operation(summary = "Create a note")
  @ApiResponse(responseCode = "201", description = "Note created")
  ResponseEntity<NoteResponseDTO> create(@Valid @RequestBody CreateNoteRequestDTO request) {
    var note = notepadAPI.create(request.toDomain());
    return ResponseEntity.status(HttpStatus.CREATED).body(NoteResponseDTO.from(note));
  }

  @GetMapping("/{id}")
  @Operation(summary = "Find a note by ID")
  @ApiResponse(responseCode = "200", description = "Note found")
  @ApiResponse(responseCode = "404", description = "Note not found")
  NoteResponseDTO findById(@PathVariable long id) {
    return NoteResponseDTO.from(notepadAPI.findById(id));
  }

  @GetMapping
  @Operation(summary = "List notes with pagination")
  @ApiResponse(responseCode = "200", description = "Page of notes")
  NotePageResponseDTO list(
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    return NotePageResponseDTO.from(notepadAPI.list(page, size));
  }

  @PutMapping("/{id}")
  @Operation(summary = "Update a note")
  @ApiResponse(responseCode = "200", description = "Note updated")
  @ApiResponse(responseCode = "404", description = "Note not found")
  NoteResponseDTO update(@PathVariable long id, @Valid @RequestBody UpdateNoteRequestDTO request) {
    return NoteResponseDTO.from(notepadAPI.update(id, request.toDomain()));
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @Operation(summary = "Delete a note")
  @ApiResponse(responseCode = "204", description = "Note deleted")
  @ApiResponse(responseCode = "404", description = "Note not found")
  void delete(@PathVariable long id) {
    notepadAPI.delete(id);
  }
}
