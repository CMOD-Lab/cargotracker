package org.eclipse.cargotracker.interfaces;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;

/**
 * Jakarta Faces configuration.
 *
 * <p>Containerization Note (blocker-9 / cz-java-0064): This class uses CDI @ApplicationScoped
 * instead of EJB @Singleton to avoid JVM-level singleton state that causes inconsistencies when
 * scaling containers horizontally on GKE Autopilot. Any shared/cached state should be stored in
 * Google Cloud Memorystore (Redis), with connection details injected via Workload Identity and
 * Secret Manager.
 */
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {}
