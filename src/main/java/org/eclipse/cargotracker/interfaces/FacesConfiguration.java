package org.eclipse.cargotracker.interfaces;

// cz-java-0064: @ApplicationScoped CDI bean - state externalized via Azure Cache for Redis.
// Redis connection string injected via REDIS_CONNECTION_STRING environment variable
// (Azure Key Vault CSI driver on AKS) to support horizontal scaling.
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;

/** Jakarta Faces configuration. * */
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {}
