package org.eclipse.cargotracker.interfaces;

// cz-java-0064: @ApplicationScoped is used (not @Singleton) to avoid singleton state storage
// inconsistencies when scaling containers horizontally on EKS.
// Any shared state should be externalized to Amazon ElastiCache (Redis) via environment variables
// REDIS_HOST and REDIS_PORT injected through Kubernetes ConfigMaps and Secrets.
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;

/** Jakarta Faces configuration. * */
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {}
