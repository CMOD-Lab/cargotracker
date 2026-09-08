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
 *
 * <p>Exposes GET /rest/health returning a JSON status response.
 * Use this endpoint in Kubernetes liveness and readiness probe configuration:
 *
 * <pre>
 * livenessProbe:
 *   httpGet:
 *     path: /cargo-tracker/rest/health
 *     port: 8080
 * readinessProbe:
 *   httpGet:
 *     path: /cargo-tracker/rest/health
 *     port: 8080
 * </pre>
 */
@ApplicationScoped
@Path("/health")
public class HealthCheckResource {

  /**
   * Returns HTTP 200 with a JSON body indicating the application is UP.
   *
   * @return JSON health status response
   */
  @GET
  @Produces(MediaType.APPLICATION_JSON)
  public Response health() {
    Map<String, Object> status = new LinkedHashMap<>();
    status.put("status", "UP");
    status.put("timestamp", Instant.now().toString());
    status.put("application", "cargo-tracker");
    return Response.ok(status).build();
  }
}
