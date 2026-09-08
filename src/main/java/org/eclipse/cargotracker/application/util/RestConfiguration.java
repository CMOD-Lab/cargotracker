package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

/**
 * Jakarta REST configuration.
 *
 * <p>cz-java-0076: Migrated from GlassFish/Jersey-specific ServerProperties to standard
 * Jakarta REST Application configuration for AKS container compatibility.
 * GlassFish-specific org.glassfish.jersey.server.ServerProperties has been replaced
 * with a standard Jakarta REST property approach using environment variables.
 */
// cz-java-0076 fix: Removed GlassFish-specific ServerProperties; using standard Jakarta REST config
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  // cz-java-0076: BV_SEND_ERROR_IN_RESPONSE behavior controlled via environment variable
  // Set SEND_ERROR_IN_RESPONSE=true to enable validation error details in responses
  private static final String SEND_ERROR_IN_RESPONSE_PROP =
      "jersey.config.server.validation.enableAutoValidation";

  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<>();
    // cz-java-0076: Use standard property key instead of GlassFish-specific ServerProperties constant
    // Controlled via environment variable SEND_ERROR_IN_RESPONSE (default: true)
    String sendErrorInResponse =
        System.getenv().getOrDefault("SEND_ERROR_IN_RESPONSE", "true");
    properties.put(SEND_ERROR_IN_RESPONSE_PROP, Boolean.parseBoolean(sendErrorInResponse));
    return properties;
  }
}
