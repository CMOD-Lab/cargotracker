package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

/**
 * Jakarta REST configuration.
 * cz-java-0076: Removed GlassFish-specific ServerProperties dependency (org.glassfish.jersey.server.ServerProperties).
 * Replaced with standard Jakarta EE Application configuration to ensure compatibility
 * with containerized environments on Amazon EKS using embedded Tomcat (Spring Boot) or
 * other container runtimes. Bean validation error responses are now handled via
 * standard Jakarta EE mechanisms.
 */
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<String, Object>();
    // cz-java-0076: Replaced GlassFish-specific ServerProperties.BV_SEND_ERROR_IN_RESPONSE
    // with a portable property key for bean validation error responses.
    properties.put("jersey.config.server.validation.enableDefaultValidationErrorEntityProvider", true);
    return properties;
  }
}
