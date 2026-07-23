package org.eclipse.cargotracker.interfaces.health;

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
 * Health check endpoint for containerization readiness.
 * Provides liveness and readiness probes for AKS deployment.
 * Accessible at: GET /rest/health
 */
@ApplicationScoped
@Path("/health")
public class HealthCheckResource {

  /**
   * Health check endpoint returning application status.
   * Used by Kubernetes liveness and readiness probes on AKS.
   *
   * @return HTTP 200 with JSON status body when application is healthy
   */
  @GET
  @Produces(MediaType.APPLICATION_JSON)
  public Response health() {
    Map<String, Object> healthStatus = new LinkedHashMap<>();
    healthStatus.put("status", "UP");
    healthStatus.put("application", "cargo-tracker");
    healthStatus.put("timestamp", Instant.now().toString());
    return Response.ok(healthStatus).build();
  }
}
