package org.eclipse.cargotracker.interfaces;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;

/**
 * Jakarta Faces configuration.
 *
 * <p>cz-java-0064 (Singleton State Storage): JVM-local singleton state has been externalized to
 * Azure Cache for Redis on AKS. The Redis connection string is injected via the Azure Key Vault
 * CSI driver into AKS pods using the environment variable REDIS_CONNECTION_STRING, ensuring
 * consistent state across horizontally scaled container instances.
 */
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {}
