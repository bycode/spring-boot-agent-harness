package nl.jinsoo.template.notepad.internal;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;
import nl.jinsoo.template.notepad.Note;
import nl.jinsoo.template.notepad.Page;

class InMemoryNotePersistence implements NotePersistencePort {

  private final Map<Long, Note> store = new HashMap<>();
  private final AtomicLong sequence = new AtomicLong(1);

  @Override
  public Note save(Note note) {
    var id = note.id() != null ? note.id() : sequence.getAndIncrement();
    var saved = new Note(id, note.title(), note.body(), note.createdAt(), note.updatedAt());
    store.put(id, saved);
    return saved;
  }

  @Override
  public Optional<Note> findById(long id) {
    return Optional.ofNullable(store.get(id));
  }

  @Override
  public Page<Note> findAll(int page, int size) {
    var all = new ArrayList<>(store.values());
    all.sort(
        Comparator.comparing(Note::createdAt, Comparator.nullsLast(Comparator.reverseOrder())));
    int start = page * size;
    int end = Math.min(start + size, all.size());
    var content = start < all.size() ? all.subList(start, end) : List.<Note>of();
    int totalPages = size > 0 ? (int) Math.ceil((double) all.size() / size) : 0;
    return new Page<>(content, page, size, all.size(), totalPages);
  }

  @Override
  public boolean deleteById(long id) {
    return store.remove(id) != null;
  }
}
