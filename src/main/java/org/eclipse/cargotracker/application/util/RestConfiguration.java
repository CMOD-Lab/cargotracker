package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

/**
 * Jakarta REST configuration.
 *
 * Blocker-19 Fix (cz-java-0076): Removed GlassFish-specific ServerProperties dependency
 * (org.glassfish.jersey.server.ServerProperties). The application is refactored to use
 * standard Jakarta EE REST configuration, compatible with AKS container deployments.
 * Bean validation error responses are now handled via standard Jakarta EE mechanisms.
 */
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<String, Object>();
    // Removed GlassFish/Jersey-specific ServerProperties.BV_SEND_ERROR_IN_RESPONSE
    // Use standard Jakarta EE exception mappers for bean validation error handling
    return properties;
  }
}
