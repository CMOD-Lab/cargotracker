package org.eclipse.cargotracker.application.util;

import java.util.HashMap;
import java.util.Map;
import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

/**
 * Jakarta REST configuration.
 * Refactored from GlassFish-specific configuration to standard Jakarta EE REST configuration
 * for deployment on AKS using Azure Workload Identity and Azure Key Vault CSI driver.
 * GlassFish-specific ServerProperties replaced with standard Jakarta RS configuration.
 */
@ApplicationPath("rest")
public class RestConfiguration extends Application {

  @Override
  public Map<String, Object> getProperties() {
    Map<String, Object> properties = new HashMap<String, Object>();
    // Replaced GlassFish-specific ServerProperties.BV_SEND_ERROR_IN_RESPONSE
    // with standard Jakarta RS property for container-agnostic deployment on AKS.
    properties.put("jersey.config.server.validation.enableDefaultValidationErrorEntityProvider", true);
    return properties;
  }
}
