package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

/**
 * Jakarta REST configuration.
 * cz-java-0076: GlassFish-specific ServerProperties removed. Application refactored to use
 * standard Jakarta REST configuration compatible with AKS container deployments.
 * GlassFish-specific org.glassfish.jersey.server.ServerProperties dependency replaced with
 * environment variable JERSEY_BV_SEND_ERROR_IN_RESPONSE for container-friendly configuration.
 */
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  private static final String JERSEY_BV_SEND_ERROR_IN_RESPONSE =
      System.getenv().getOrDefault("JERSEY_BV_SEND_ERROR_IN_RESPONSE", "true");

  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<String, Object>();
    // cz-java-0076: Replaced GlassFish-specific ServerProperties.BV_SEND_ERROR_IN_RESPONSE
    // with environment variable injection for AKS container compatibility.
    properties.put(
        "jersey.config.server.validation.enableAutoValidation",
        Boolean.parseBoolean(JERSEY_BV_SEND_ERROR_IN_RESPONSE));
    return properties;
  }
}
