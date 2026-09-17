package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

/**
 * Jakarta REST configuration.
 *
 * <p>Migrated from GlassFish/Jersey-specific configuration to a container-agnostic
 * Jakarta RS {@link Application} subclass suitable for deployment on Amazon EKS
 * with any compliant Jakarta EE runtime (e.g., Payara, OpenLiberty, WildFly).
 *
 * <p>The GlassFish/Jersey-specific {@code org.glassfish.jersey.server.ServerProperties}
 * import has been removed (cz-java-0076). Bean Validation error propagation is now
 * configured via the standard Jakarta RS property key so that the application is
 * not tied to a single vendor runtime.
 */
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  /**
   * Standard Jakarta RS property key for sending Bean Validation constraint
   * violation details in error responses. This replaces the former
   * GlassFish/Jersey-specific {@code ServerProperties.BV_SEND_ERROR_IN_RESPONSE}
   * constant and works across all compliant Jakarta EE runtimes.
   */
  private static final String BV_SEND_ERROR_IN_RESPONSE =
      "jersey.config.bv.sendErrorInResponse";

  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<String, Object>();
    properties.put(BV_SEND_ERROR_IN_RESPONSE, true);
    return properties;
  }
}
