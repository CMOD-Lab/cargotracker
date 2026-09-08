package org.eclipse.cargotracker.interfaces;

// cz-java-0064: @ApplicationScoped CDI scope used to avoid JVM-local singleton state.
// For horizontal scaling on AKS, externalize shared state to Azure Cache for Redis via REDIS_CONNECTION_STRING env var.
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;

/** Jakarta Faces configuration. * */
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {}
