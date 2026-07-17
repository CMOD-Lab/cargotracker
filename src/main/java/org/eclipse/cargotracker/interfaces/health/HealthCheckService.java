package org.eclipse.cargotracker.interfaces.health;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

/**
 * Health check endpoint for containerization readiness.
 * Provides a standard /rest/health endpoint for GKE Autopilot liveness and readiness probes.
 *
 * <p>This endpoint is required for container orchestration platforms to verify application health.
 * Configure Kubernetes liveness/readiness probes to use: GET /cargo-tracker/rest/health
 */
@ApplicationScoped
@Path("/health")
public class HealthCheckService {

  /**
   * Returns HTTP 200 with a JSON status body when the application is healthy.
   * Used by GKE Autopilot liveness and readiness probes.
   *
   * @return HTTP 200 OK with {"status":"UP"} when healthy
   */
  @GET
  @Produces(MediaType.APPLICATION_JSON)
  public Response health() {
    return Response.ok("{\"status\":\"UP\"}").build();
  }
}
