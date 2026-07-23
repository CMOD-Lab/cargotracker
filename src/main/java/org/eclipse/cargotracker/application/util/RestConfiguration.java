package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

/**
 * Jakarta REST configuration.
 * Migrated from GlassFish-specific Jersey configuration to standard Jakarta EE REST Application
 * for containerized deployment on Amazon EKS with embedded Tomcat (Spring Boot compatible).
 */
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<String, Object>();
    // BV_SEND_ERROR_IN_RESPONSE: send Bean Validation errors in REST responses
    // Previously used GlassFish/Jersey-specific ServerProperties constant;
    // now using the standard property key string for container portability.
    properties.put("jersey.config.server.validation.enableDefaultValidationErrorEntityProvider", true);
    return properties;
  }
}
