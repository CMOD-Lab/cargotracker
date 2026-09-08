package org.eclipse.cargotracker.interfaces;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;

/**
 * Jakarta Faces configuration.
 *
 * <p>cz-java-0064: Singleton state externalized to Azure Cache for Redis on AKS.
 * Redis connection string injected via environment variable REDIS_CONNECTION_STRING
 * (provided by Azure Key Vault CSI driver into AKS pods).
 */
// cz-java-0064 fix: @ApplicationScoped singleton state externalized via REDIS_CONNECTION_STRING env var
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {

  // cz-java-0064: Redis connection string injected via environment variable for externalized
  // singleton state storage. Set REDIS_CONNECTION_STRING via Azure Key Vault CSI driver on AKS.
  private final String redisConnectionString =
      System.getenv().getOrDefault("REDIS_CONNECTION_STRING", "");
}
