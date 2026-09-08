package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

/**
 * Jakarta REST configuration.
 * cz-java-0076: Removed GlassFish/Jersey-specific ServerProperties dependency.
 * Migrated to standard Jakarta REST Application configuration for AKS container deployment.
 * Application is now portable across container runtimes without GlassFish-specific dependencies.
 */
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<String, Object>();
    // cz-java-0076: Removed GlassFish-specific ServerProperties.BV_SEND_ERROR_IN_RESPONSE.
    // Use standard Jakarta REST error handling instead of GlassFish-specific server properties.
    return properties;
  }
}
