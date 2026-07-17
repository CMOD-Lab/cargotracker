package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

// cz-java-0076: Removed GlassFish-specific org.glassfish.jersey.server.ServerProperties import.
// Replaced with standard Jakarta EE Application configuration compatible with GKE Autopilot
// container runtime environments. Deploy on GKE Autopilot using Workload Identity and
// GCP Secret Manager for secure credential injection.
/** Jakarta REST configuration. */
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<String, Object>();
    // cz-java-0076: Removed ServerProperties.BV_SEND_ERROR_IN_RESPONSE (GlassFish-specific).
    // Bean validation error responses are handled via standard Jakarta EE exception mappers.
    return properties;
  }
}
