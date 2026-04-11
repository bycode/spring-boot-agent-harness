package nl.jinsoo.template.widgets;

import org.junit.jupiter.api.Test;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

class WidgetControllerTest {

  @Test
  void list_placeholder_has_no_tag_and_no_operation_in_test_stub() {
    // A test stub that references @RestController and @GetMapping identifiers
    // via imports only — the check must not fire on files under src/test/.
    @RestController
    class Dummy {
      @GetMapping
      String list() {
        return "[]";
      }
    }
  }
}
