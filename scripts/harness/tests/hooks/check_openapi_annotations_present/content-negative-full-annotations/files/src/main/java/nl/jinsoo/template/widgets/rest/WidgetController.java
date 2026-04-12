package nl.jinsoo.template.widgets.rest;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/widgets")
@Tag(name = "Widgets", description = "Reference implementation controller")
class WidgetController {

  @GetMapping
  @Operation(summary = "List widgets")
  String list() {
    return "[]";
  }

  @GetMapping("/api/widgets/{id}")
  @Operation(summary = "Find a widget by ID")
  String findById(@PathVariable long id) {
    return "{}";
  }

  @PostMapping
  @Operation(summary = "Create a widget")
  String create() {
    return "{}";
  }

  @DeleteMapping("/api/widgets/{id}")
  @Operation(summary = "Delete a widget")
  void delete(@PathVariable long id) {}
}
