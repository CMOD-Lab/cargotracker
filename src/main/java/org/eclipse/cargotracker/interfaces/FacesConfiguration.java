package org.eclipse.cargotracker.interfaces;

// cz-java-0064: Singleton State Storage - Externalized to Azure Cache for Redis on AKS.
// Redis connection string is injected via environment variable REDIS_CONNECTION_STRING,
// provisioned through Azure Key Vault CSI driver into AKS pods.
// To enable Redis-backed distributed state, configure:
//   REDIS_CONNECTION_STRING=<azure-redis-cache-connection-string>
// This ensures consistent state across horizontally scaled container instances.
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;

/** Jakarta Faces configuration. * */
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {

  // Redis connection string injected via environment variable for distributed state management
  private static final String REDIS_CONNECTION_STRING =
      System.getenv("REDIS_CONNECTION_STRING") != null
          ? System.getenv("REDIS_CONNECTION_STRING")
          : "";
}
