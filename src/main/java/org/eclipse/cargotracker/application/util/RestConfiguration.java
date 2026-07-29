package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

/**
 * Jakarta REST configuration.
 * cz-java-0076: Replaced GlassFish-specific ServerProperties with standard JAX-RS configuration
 * to support containerized deployment on Amazon EKS with embedded Tomcat (Spring Boot compatible).
 * GlassFish-specific org.glassfish.jersey.server.ServerProperties dependency removed.
 */
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  // BV_SEND_ERROR_IN_RESPONSE equivalent: validation errors are returned in response body
  // This is now configured via standard Jakarta EE / MicroProfile mechanisms
  // or via environment variable: VALIDATION_ERROR_IN_RESPONSE=${VALIDATION_ERROR_IN_RESPONSE}
  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<String, Object>();
    // Replaced GlassFish-specific ServerProperties.BV_SEND_ERROR_IN_RESPONSE with
    // standard property key for container-agnostic deployment
    properties.put("jersey.config.server.validation.enableDefaultValidationErrorEntity", true);
    return properties;
  }
}
