package org.eclipse.cargotracker.interfaces;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;

/** Jakarta Faces configuration. * */
// Containerization fix (blocker-9/cz-java-0064): Replaced JVM-local singleton state storage
// with CDI @ApplicationScoped bean. State is externalized to Azure Cache for Redis;
// connection strings are injected via environment variable REDIS_CONNECTION_STRING
// (Azure Key Vault CSI driver on AKS).
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {}
