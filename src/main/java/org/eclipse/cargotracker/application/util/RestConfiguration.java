package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;
// cz-java-0076: Removed GlassFish-specific ServerProperties import (org.glassfish.jersey.server.ServerProperties).
// Replaced with a container-agnostic JAX-RS Application configuration suitable for EKS deployment.
// BV_SEND_ERROR_IN_RESPONSE is now controlled via the JERSEY_BV_SEND_ERROR environment variable.

/** Jakarta REST configuration. */
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<String, Object>();
    // cz-java-0076: Use environment variable instead of GlassFish-specific ServerProperties constant.
    // Set JERSEY_BV_SEND_ERROR=true in Kubernetes ConfigMap/Secret to enable BV error responses.
    String bvSendError = System.getenv("JERSEY_BV_SEND_ERROR");
    if (bvSendError != null) {
      properties.put("jersey.config.server.validation.output.severity", bvSendError);
    }
    return properties;
  }
}
