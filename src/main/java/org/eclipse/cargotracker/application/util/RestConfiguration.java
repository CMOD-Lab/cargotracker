package org.eclipse.cargotracker.application.util;

import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

/**
 * Jakarta REST configuration.
 *
 * Containerization fix (blocker-19/cz-java-0076): Removed GlassFish/Jersey-specific
 * ServerProperties dependency. Replaced with a standard JAX-RS Application class
 * to ensure compatibility across container runtime environments (AKS, Payara, OpenLiberty).
 * The application is containerized and deployed on AKS using Azure Workload Identity
 * and the Azure Key Vault CSI driver for secure secret management.
 */
@ApplicationPath("rest")
public class RestConfiguration extends Application {}
