package org.eclipse.cargotracker.interfaces.health;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

/**
 * Health check endpoint for containerization readiness.
 *
 * <p>This endpoint is required for container orchestration platforms (e.g., GKE Autopilot) to
 * perform liveness and readiness probes. It exposes a simple HTTP GET endpoint at /rest/health
 * that returns a JSON status response indicating the application is running.
 */
@ApplicationScoped
@Path("/health")
public class HealthCheckResource {

  /**
   * Health check endpoint.
   *
   * @return HTTP 200 with JSON status body when the application is healthy.
   */
  @GET
  @Produces(MediaType.APPLICATION_JSON)
  public Response health() {
    return Response.ok("{\"status\":\"UP\",\"application\":\"cargo-tracker\"}").build();
  }
}
