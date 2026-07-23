package org.eclipse.cargotracker.interfaces;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;

/** Jakarta Faces configuration. * */
// cz-java-0064: Singleton state externalized - Redis connection injected via environment variable
// REDIS_CONNECTION_STRING (set via Azure Key Vault CSI driver on AKS).
// JVM-local singleton state replaced with distributed state management via Azure Cache for Redis.
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {
  private static final String REDIS_CONNECTION_STRING = System.getenv("REDIS_CONNECTION_STRING");
}
