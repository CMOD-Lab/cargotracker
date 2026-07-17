package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;
// Containerization fix (blocker-19, cz-java-0076): Removed GlassFish/Jersey-specific ServerProperties
// dependency to ensure compatibility across container runtime environments on AKS.
// Migrated to standard Jakarta REST Application configuration without server-specific properties.

/** Jakarta REST configuration. */
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<String, Object>();
    // Removed GlassFish-specific ServerProperties.BV_SEND_ERROR_IN_RESPONSE
    // Use standard Jakarta REST configuration for container portability on AKS.
    return properties;
  }
}
