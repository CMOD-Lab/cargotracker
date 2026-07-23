package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

/**
 * Jakarta REST configuration.
 * cz-java-0076: Removed GlassFish-specific org.glassfish.jersey.server.ServerProperties dependency.
 * Replaced with standard Jakarta RS Application configuration compatible with any Jakarta EE
 * container runtime (e.g., containerized Spring Boot on EKS with embedded Tomcat).
 * Bean Validation error responses are now handled via standard Jakarta RS ExceptionMapper.
 */
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<String, Object>();
    // cz-java-0076: Removed GlassFish/Jersey-specific ServerProperties.BV_SEND_ERROR_IN_RESPONSE.
    // Use a standard Jakarta RS ExceptionMapper for ConstraintViolationException handling instead.
    return properties;
  }
}
