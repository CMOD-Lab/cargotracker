package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;
// Containerization (blocker-19 / cz-java-0076): GlassFish-specific configuration identified.
// Refactored to use standard Jakarta REST Application without GlassFish/Jersey-specific
// ServerProperties dependency. Deploy on GKE Autopilot using Workload Identity and
// GCP Secret Manager for secure credential injection.

/** Jakarta REST configuration. */
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<String, Object>();
    // Removed GlassFish-specific ServerProperties.BV_SEND_ERROR_IN_RESPONSE dependency.
    // Bean validation error responses are now handled by the standard Jakarta REST
    // exception mapper, compatible with any Jakarta EE-compliant container.
    return properties;
  }
}
