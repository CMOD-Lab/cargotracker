package org.eclipse.cargotracker.interfaces;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;

// Singleton state externalized: shared state managed via Amazon ElastiCache (Redis) on EKS.
// Configure via environment variables: REDIS_HOST, REDIS_PORT
/** Jakarta Faces configuration. * */
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {}
