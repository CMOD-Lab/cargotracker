package org.eclipse.cargotracker.application.util;

import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

/**
 * Jakarta REST configuration.
 * GKE Autopilot: Removed GlassFish-specific ServerProperties dependency.
 * Application is now portable across container runtimes (GKE Autopilot, etc.).
 */
@ApplicationPath("rest")
public class RestConfiguration extends Application {}
