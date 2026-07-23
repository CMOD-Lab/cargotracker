package org.eclipse.cargotracker.application.util;

import jakarta.ws.rs.ApplicationPath;
import jakarta.ws.rs.core.Application;

/**
 * Jakarta REST configuration.
 *
 * <p>cz-java-0076 (GlassFish/Application Server): GlassFish-specific Jersey ServerProperties
 * configuration has been replaced with a standard Jakarta EE JAX-RS Application class. The
 * application is containerized and deployed on AKS using Azure Workload Identity and the Azure
 * Key Vault CSI driver for secure secret management.
 */
@ApplicationPath("rest")
public class RestConfiguration extends Application {}
