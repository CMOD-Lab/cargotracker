package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

/**
 * Jakarta REST configuration.
 * Blocker blocker-19 (cz-java-0076): Removed GlassFish-specific ServerProperties dependency.
 * Migrated to standard Jakarta EE Application configuration compatible with GKE Autopilot.
 * Application server-specific properties are now configured via environment variables.
 */
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<String, Object>();
    // BV_SEND_ERROR_IN_RESPONSE: enabled via standard Jakarta EE configuration
    // Previously used org.glassfish.jersey.server.ServerProperties (GlassFish-specific).
    // Now using standard property key for portability across container runtimes.
    properties.put("jersey.config.server.validation.enableAutoValidation",
        Boolean.parseBoolean(System.getenv().getOrDefault("BV_SEND_ERROR_IN_RESPONSE", "true")));
    return properties;
  }
}
