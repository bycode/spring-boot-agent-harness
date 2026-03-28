package nl.jinsoo.template.notepad.persistence;

import java.util.Optional;
import nl.jinsoo.template.notepad.Note;
import nl.jinsoo.template.notepad.Page;
import nl.jinsoo.template.notepad.internal.NotePersistencePort;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Component;

@Component
class NoteRepositoryAdapter implements NotePersistencePort {

  private final NoteRepository repository;

  NoteRepositoryAdapter(NoteRepository repository) {
    this.repository = repository;
  }

  @Override
  public Note save(Note note) {
    return repository.save(NoteEntity.from(note)).toDomain();
  }

  @Override
  public Optional<Note> findById(long id) {
    return repository.findById(id).map(NoteEntity::toDomain);
  }

  @Override
  public Page<Note> findAll(int page, int size) {
    var pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "createdAt"));
    var springPage = repository.findAll(pageable);
    var notes = springPage.getContent().stream().map(NoteEntity::toDomain).toList();
    return new Page<>(
        notes,
        springPage.getNumber(),
        springPage.getSize(),
        springPage.getTotalElements(),
        springPage.getTotalPages());
  }

  @Override
  public boolean deleteById(long id) {
    return repository.deleteAndReturnCount(id) > 0;
  }
}
