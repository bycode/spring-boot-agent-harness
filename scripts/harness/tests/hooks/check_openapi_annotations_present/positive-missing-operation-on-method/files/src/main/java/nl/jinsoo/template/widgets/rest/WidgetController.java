package nl.jinsoo.template.widgets.rest;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/widgets")
@Tag(name = "Widgets")
class WidgetController {

  @GetMapping
  @Operation(summary = "List widgets")
  String list() {
    return "[]";
  }

  @GetMapping("/{id}")
  String findById(@PathVariable long id) {
    return "{}";
  }
}
