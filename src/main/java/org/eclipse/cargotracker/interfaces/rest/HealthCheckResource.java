package org.eclipse.cargotracker.interfaces.rest;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Health check endpoint for containerized deployment on Amazon EKS.
 * Provides liveness and readiness probes for Kubernetes.
 *
 * <p>Endpoints:
 * <ul>
 *   <li>GET /rest/health - Overall health status</li>
 *   <li>GET /rest/health/live - Liveness probe</li>
 *   <li>GET /rest/health/ready - Readiness probe</li>
 * </ul>
 */
@ApplicationScoped
@Path("/health")
public class HealthCheckResource {

  @GET
  @Produces(MediaType.APPLICATION_JSON)
  public Response health() {
    Map<String, Object> healthStatus = new LinkedHashMap<>();
    healthStatus.put("status", "UP");
    healthStatus.put("timestamp", Instant.now().toString());
    healthStatus.put("application", "cargo-tracker");
    return Response.ok(healthStatus).build();
  }

  @GET
  @Path("/live")
  @Produces(MediaType.APPLICATION_JSON)
  public Response liveness() {
    Map<String, Object> livenessStatus = new LinkedHashMap<>();
    livenessStatus.put("status", "UP");
    livenessStatus.put("timestamp", Instant.now().toString());
    livenessStatus.put("check", "liveness");
    return Response.ok(livenessStatus).build();
  }

  @GET
  @Path("/ready")
  @Produces(MediaType.APPLICATION_JSON)
  public Response readiness() {
    Map<String, Object> readinessStatus = new LinkedHashMap<>();
    readinessStatus.put("status", "UP");
    readinessStatus.put("timestamp", Instant.now().toString());
    readinessStatus.put("check", "readiness");
    return Response.ok(readinessStatus).build();
  }
}
