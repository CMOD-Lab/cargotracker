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
 * Provides a standard /health HTTP GET endpoint returning JSON status response.
 * Used by Kubernetes liveness and readiness probes on Amazon EKS.
 *
 * Endpoint: GET /rest/health
 * Returns HTTP 200 with {"status":"UP"} when the application is healthy.
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
}
