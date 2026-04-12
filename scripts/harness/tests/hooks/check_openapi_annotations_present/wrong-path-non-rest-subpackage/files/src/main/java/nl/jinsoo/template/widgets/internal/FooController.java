package nl.jinsoo.template.widgets.internal;

// Not in a rest/ subpackage — internal helper named with a Controller suffix for
// historical reasons. The check must ignore files outside rest/*Controller.java.
class FooController {

  String list() {
    return "[]";
  }
}
