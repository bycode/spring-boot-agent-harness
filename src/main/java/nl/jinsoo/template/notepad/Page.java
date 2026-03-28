package nl.jinsoo.template.notepad;

import java.util.List;

public record Page<T>(List<T> content, int page, int size, long totalElements, int totalPages) {

  public Page {
    content = List.copyOf(content);
  }
}
