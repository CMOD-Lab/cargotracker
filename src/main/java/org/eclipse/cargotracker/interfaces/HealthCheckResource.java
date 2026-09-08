package org.eclipse.cargotracker.interfaces;

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
 * Health check endpoint for containerized deployment on AKS.
 * Provides liveness and readiness probes for Kubernetes.
 * Accessible at: GET /rest/health
 */
@ApplicationScoped
@Path("/health")
public class HealthCheckResource {

  /**
   * Health check endpoint returning application status.
   * Used by Kubernetes liveness and readiness probes.
   *
   * @return HTTP 200 with JSON status body when healthy
   */
  @GET
  @Produces(MediaType.APPLICATION_JSON)
  public Response health() {
    Map<String, Object> status = new LinkedHashMap<>();
    status.put("status", "UP");
    status.put("application", "cargo-tracker");
    status.put("timestamp", Instant.now().toString());
    return Response.ok(status).build();
  }
}
