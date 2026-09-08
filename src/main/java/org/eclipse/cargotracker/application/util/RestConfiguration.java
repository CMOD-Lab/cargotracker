package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;
// cz-java-0076: Removed GlassFish-specific org.glassfish.jersey.server.ServerProperties import.
// Replaced with standard Jakarta EE properties to support containerized deployment on AKS
// without GlassFish-specific runtime dependencies.

/** Jakarta REST configuration. */
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<String, Object>();
    // cz-java-0076: Replaced GlassFish-specific ServerProperties.BV_SEND_ERROR_IN_RESPONSE
    // with a standard property key string to remove GlassFish runtime dependency.
    properties.put("jersey.config.bv.sendErrorInResponse", true);
    return properties;
  }
}
