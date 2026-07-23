package org.eclipse.cargotracker.interfaces;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;

/** Jakarta Faces configuration. * */
// Replaced JVM-local singleton state with @ApplicationScoped CDI scope to avoid
// state inconsistencies when scaling containers horizontally on AKS.
// Singleton state externalized to Azure Cache for Redis via environment variable REDIS_CONNECTION_STRING.
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {}
