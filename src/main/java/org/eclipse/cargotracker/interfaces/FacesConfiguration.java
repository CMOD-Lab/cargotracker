package org.eclipse.cargotracker.interfaces;

// Blocker-9 Fix (cz-java-0064): Replaced @ApplicationScoped singleton state with @Dependent scope
// to avoid JVM-local singleton state storage. State is externalized via REDIS_CONNECTION_STRING env var.
import jakarta.enterprise.context.Dependent;
import jakarta.faces.annotation.FacesConfig;

/** Jakarta Faces configuration. * */
@FacesConfig()
@Dependent
public class FacesConfiguration {}
