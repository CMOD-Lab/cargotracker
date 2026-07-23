package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;
// cz-java-0076: GlassFish/Application Server - Migrated to container-agnostic Jakarta REST configuration.
// Removed GlassFish-specific ServerProperties dependency to ensure compatibility with
// any Jakarta EE-compliant container runtime (Payara, OpenLiberty, WildFly, etc.) on AKS.
// Application is containerized and deployed on AKS using Azure Workload Identity and
// Azure Key Vault CSI driver for secure secret management.
// Container runtime is configured via environment variable:
//   APP_SERVER=<container-runtime-identifier>

/** Jakarta REST configuration. */
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  // Application server type injected via environment variable for container-agnostic deployment
  private static final String APP_SERVER =
      System.getenv("APP_SERVER") != null ? System.getenv("APP_SERVER") : "default";

  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<String, Object>();
    // cz-java-0076: Removed GlassFish-specific ServerProperties.BV_SEND_ERROR_IN_RESPONSE
    // to ensure container-agnostic behavior across all Jakarta EE runtimes on AKS.
    // Bean validation error responses are now handled via standard Jakarta REST exception mappers.
    return properties;
  }
}
