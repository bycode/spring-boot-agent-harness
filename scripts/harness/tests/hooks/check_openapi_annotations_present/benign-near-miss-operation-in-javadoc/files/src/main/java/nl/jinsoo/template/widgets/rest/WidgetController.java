package nl.jinsoo.template.widgets.rest;

import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/widgets")
@Tag(name = "Widgets")
class WidgetController {

  /**
   * Lists widgets.
   *
   * <p>Note: this endpoint should eventually carry a Swagger @Operation annotation,
   * but for now we rely on the class-level @Tag only.
   */
  @GetMapping
  String list() {
    return "[]";
  }
}
