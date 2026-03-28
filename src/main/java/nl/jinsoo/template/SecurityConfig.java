package nl.jinsoo.template;

import jakarta.annotation.PostConstruct;
import java.nio.charset.StandardCharsets;
import java.util.List;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.jwt.JwtClaimValidator;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

@Configuration(proxyBeanMethods = false)
public class SecurityConfig {

  private final String secretKey;

  private final String issuerUri;

  public SecurityConfig(
      @Value("${jwt.secret-key:}") String secretKey,
      @Value("${spring.security.oauth2.resourceserver.jwt.issuer-uri:}") String issuerUri) {
    this.secretKey = secretKey;
    this.issuerUri = issuerUri;
  }

  @PostConstruct
  void validateJwtConfiguration() {
    validateJwtProperties(secretKey, issuerUri);
  }

  static void validateJwtProperties(String secretKey, String issuerUri) {
    boolean hasSecretKey = secretKey != null && !secretKey.isBlank();
    boolean hasIssuerUri = issuerUri != null && !issuerUri.isBlank();
    if (hasSecretKey && hasIssuerUri) {
      throw new IllegalStateException(
          "Ambiguous JWT configuration: both jwt.secret-key and"
              + " spring.security.oauth2.resourceserver.jwt.issuer-uri are set."
              + " Configure exactly one.");
    }
    if (!hasSecretKey && !hasIssuerUri) {
      throw new IllegalStateException(
          "Missing JWT configuration: set either jwt.secret-key (dev/HMAC)"
              + " or spring.security.oauth2.resourceserver.jwt.issuer-uri (prod/OIDC).");
    }
  }

  @Bean
  SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    return http.authorizeHttpRequests(
            auth ->
                auth.requestMatchers(
                        "/actuator/health",
                        "/actuator/info",
                        "/v3/api-docs",
                        "/v3/api-docs/**",
                        "/swagger-ui.html",
                        "/swagger-ui/**")
                    .permitAll()
                    .anyRequest()
                    .authenticated())
        .sessionManagement(
            session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .csrf(AbstractHttpConfigurer::disable)
        .cors(Customizer.withDefaults())
        .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
        .build();
  }

  @Bean
  CorsConfigurationSource corsConfigurationSource(
      @Value("${cors.allowed-origins:http://localhost:3000,http://localhost:5173}")
          List<String> allowedOrigins) {
    var config = new CorsConfiguration();
    config.setAllowedOriginPatterns(allowedOrigins);
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
    config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
    config.setMaxAge(3600L);
    var source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/api/**", config);
    return source;
  }

  @Bean
  @ConditionalOnProperty("jwt.secret-key")
  JwtDecoder jwtDecoder(
      @Value("${jwt.secret-key}") String secretKey, @Value("${jwt.audience:}") String audience) {
    var key = new SecretKeySpec(secretKey.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
    var decoder = NimbusJwtDecoder.withSecretKey(key).build();
    if (!audience.isBlank()) {
      var audienceValidator =
          new JwtClaimValidator<List<String>>("aud", aud -> aud != null && aud.contains(audience));
      decoder.setJwtValidator(
          new DelegatingOAuth2TokenValidator<>(JwtValidators.createDefault(), audienceValidator));
    }
    return decoder;
  }
}
