package nl.jinsoo.template.widgets.rest;

import io.swagger.v3.oas.annotations.Operation;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/widgets")
class WidgetController {

  @GetMapping
  @Operation(summary = "List widgets")
  String list() {
    return "[]";
  }
}
