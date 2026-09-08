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
 * Health check endpoint for container liveness and readiness probes.
 * Provides a standard /rest/health endpoint returning JSON status for GKE Autopilot
 * liveness and readiness probes.
 */
@ApplicationScoped
@Path("/health")
public class HealthCheckResource {

  /**
   * Health check endpoint.
   * Returns HTTP 200 with JSON body {"status":"UP"} when the application is healthy.
   *
   * @return HTTP 200 OK with health status JSON
   */
  @GET
  @Produces(MediaType.APPLICATION_JSON)
  public Response health() {
    Map<String, Object> healthStatus = new LinkedHashMap<>();
    healthStatus.put("status", "UP");
    healthStatus.put("timestamp", Instant.now().toString());
    healthStatus.put("application", "cargo-tracker");
    return Response.ok(healthStatus).build();
  }
}
