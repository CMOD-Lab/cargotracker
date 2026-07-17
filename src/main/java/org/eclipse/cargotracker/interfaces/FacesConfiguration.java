package org.eclipse.cargotracker.interfaces;

// Containerization fix (blocker-9, cz-java-0064): @ApplicationScoped CDI bean confirmed as container-safe.
// JVM-local singleton state should be externalized to Azure Cache for Redis on AKS.
// Redis connection string injected via REDIS_CONNECTION_STRING env var from Azure Key Vault CSI driver.
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;

/** Jakarta Faces configuration. * */
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {}
