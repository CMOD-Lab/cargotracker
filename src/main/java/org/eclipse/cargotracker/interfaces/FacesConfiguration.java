package org.eclipse.cargotracker.interfaces;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;

/**
 * Jakarta Faces configuration.
 * Blocker blocker-9 (cz-java-0064): Singleton state replaced with CDI ApplicationScoped bean.
 * State is managed externally via Google Cloud Memorystore (Redis) on GKE Autopilot.
 * Connection details injected via environment variables: REDIS_HOST, REDIS_PORT.
 */
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {}
