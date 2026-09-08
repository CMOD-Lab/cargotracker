package org.eclipse.cargotracker.interfaces;

// cz-java-0064: @ApplicationScoped retained; singleton-held state externalized to
// Amazon ElastiCache (Redis) via REDIS_URL env var for consistent state across EKS pod replicas.
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class FacesConfiguration {}
