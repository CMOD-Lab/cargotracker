package org.eclipse.cargotracker.interfaces;

import jakarta.faces.annotation.FacesConfig;

// GKE Autopilot: @ApplicationScoped bean - for distributed state across pods,
// use Google Cloud Memorystore (Redis) via REDIS_HOST env var instead of JVM-local state.
@FacesConfig
public class FacesConfiguration {}
