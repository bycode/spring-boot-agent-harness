package nl.jinsoo.template.notepad.persistence;

import org.springframework.data.jdbc.repository.query.Modifying;
import org.springframework.data.jdbc.repository.query.Query;
import org.springframework.data.repository.ListCrudRepository;
import org.springframework.data.repository.PagingAndSortingRepository;

interface NoteRepository
    extends ListCrudRepository<NoteEntity, Long>, PagingAndSortingRepository<NoteEntity, Long> {

  @Modifying
  @Query("DELETE FROM notes WHERE id = :id")
  int deleteAndReturnCount(long id);
}
