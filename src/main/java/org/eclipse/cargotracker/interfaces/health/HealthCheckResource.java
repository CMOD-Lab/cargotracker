package org.eclipse.cargotracker.interfaces.health;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.json.Json;
import jakarta.json.JsonObject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

/**
 * Health check endpoint for containerization readiness.
 *
 * <p>Provides a simple liveness/readiness probe at {@code GET /rest/health} that returns HTTP 200
 * with a JSON status payload. This endpoint is used by Kubernetes (AKS) liveness and readiness
 * probes to determine container health.
 *
 * <p>Example response:
 *
 * <pre>
 * {
 *   "status": "UP",
 *   "application": "cargo-tracker"
 * }
 * </pre>
 */
@ApplicationScoped
@Path("/health")
public class HealthCheckResource {

  /**
   * Returns the health status of the application.
   *
   * @return HTTP 200 with JSON body {@code {"status":"UP","application":"cargo-tracker"}}
   */
  @GET
  @Produces(MediaType.APPLICATION_JSON)
  public Response health() {
    JsonObject healthStatus =
        Json.createObjectBuilder()
            .add("status", "UP")
            .add("application", "cargo-tracker")
            .build();
    return Response.ok(healthStatus).build();
  }
}
