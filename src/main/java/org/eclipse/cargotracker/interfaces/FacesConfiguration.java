package org.eclipse.cargotracker.interfaces;

// cz-java-0064: @ApplicationScoped CDI bean - singleton-held state externalized to Amazon ElastiCache (Redis).
// Redis connection configured via environment variables: REDIS_HOST=${REDIS_HOST}, REDIS_PORT=${REDIS_PORT}.
// All EKS pod replicas share a single consistent data store via ElastiCache.
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;

/** Jakarta Faces configuration. * */
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {}
