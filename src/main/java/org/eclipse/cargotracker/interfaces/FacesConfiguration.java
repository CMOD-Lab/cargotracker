package org.eclipse.cargotracker.interfaces;

// cz-java-0064: @ApplicationScoped used instead of @Singleton to avoid singleton state storage
// inconsistencies when scaling containers horizontally on EKS.
// Any shared state should be externalized to Amazon ElastiCache (Redis) for consistency across pods.
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;

/** Jakarta Faces configuration. * */
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {}
