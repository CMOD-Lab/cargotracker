package org.eclipse.cargotracker.application.util;

import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

/**
 * Jakarta REST configuration.
 *
 * <p>Containerization Note (blocker-19 / cz-java-0076): Removed GlassFish/Jersey-specific
 * ServerProperties dependency (org.glassfish.jersey.server.ServerProperties) and replaced with a
 * standard Jakarta REST Application configuration. This ensures compatibility across container
 * runtime environments when deploying on GKE Autopilot, using Workload Identity and GCP Secret
 * Manager for secure credential injection.
 */
@ApplicationPath("rest")
public class RestConfiguration extends Application {}
