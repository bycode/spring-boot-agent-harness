package nl.jinsoo.template;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

class SecurityConfigTest {

  @Test
  void validateJwtPropertiesAllowsSecretKeyConfiguration() {
    assertDoesNotThrow(
        () ->
            SecurityConfig.validateJwtProperties("demo-signing-key-must-be-at-least-256-bits", ""));
  }

  @Test
  void validateJwtPropertiesAllowsIssuerConfiguration() {
    assertDoesNotThrow(
        () ->
            SecurityConfig.validateJwtProperties(
                "", "https://issuer.example.test/realms/template"));
  }

  @Test
  void validateJwtPropertiesRejectsAmbiguousConfiguration() {
    var exception =
        assertThrows(
            IllegalStateException.class,
            () ->
                SecurityConfig.validateJwtProperties(
                    "demo-signing-key-must-be-at-least-256-bits",
                    "https://issuer.example.test/realms/template"));

    assertEquals(
        "Ambiguous JWT configuration: both jwt.secret-key and"
            + " spring.security.oauth2.resourceserver.jwt.issuer-uri are set."
            + " Configure exactly one.",
        exception.getMessage());
  }

  @Test
  void validateJwtPropertiesRejectsMissingConfiguration() {
    var exception =
        assertThrows(
            IllegalStateException.class, () -> SecurityConfig.validateJwtProperties("", ""));

    assertEquals(
        "Missing JWT configuration: set either jwt.secret-key (dev/HMAC)"
            + " or spring.security.oauth2.resourceserver.jwt.issuer-uri (prod/OIDC).",
        exception.getMessage());
  }

  @Test
  void corsConfigurationSourceUsesAllowedOriginPatterns() {
    var config = new SecurityConfig("demo-signing-key-must-be-at-least-256-bits", "");
    var request = new MockHttpServletRequest("GET", "/api/example");
    var corsConfiguration =
        config
            .corsConfigurationSource(List.of("https://app.example.test"))
            .getCorsConfiguration(request);

    assertNotNull(corsConfiguration);
    assertEquals(List.of("https://app.example.test"), corsConfiguration.getAllowedOriginPatterns());
    assertEquals(
        List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"),
        corsConfiguration.getAllowedMethods());
  }

  @Test
  void jwtDecoderBeanCanBeCreatedFromSecretKey() {
    var config = new SecurityConfig("demo-signing-key-must-be-at-least-256-bits", "");

    assertNotNull(config.jwtDecoder("demo-signing-key-must-be-at-least-256-bits", ""));
  }

  @Test
  void jwtDecoderBeanCanBeCreatedWithAudience() {
    var config = new SecurityConfig("demo-signing-key-must-be-at-least-256-bits", "");

    assertNotNull(config.jwtDecoder("demo-signing-key-must-be-at-least-256-bits", "template-api"));
  }
}
