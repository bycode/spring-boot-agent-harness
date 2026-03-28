package nl.jinsoo.template.notepad;

import java.time.Instant;
import org.jspecify.annotations.Nullable;

public record Note(
    @Nullable Long id,
    String title,
    String body,
    @Nullable Instant createdAt,
    @Nullable Instant updatedAt) {}
