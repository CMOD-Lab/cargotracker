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
 *
 * <p>Provides a simple HTTP GET /rest/health endpoint that returns the application status.
 * This endpoint is used by Kubernetes liveness and readiness probes on EKS to determine
 * whether the container is healthy and ready to serve traffic.
 *
 * <p>Example Kubernetes probe configuration:
 * <pre>
 * livenessProbe:
 *   httpGet:
 *     path: /cargo-tracker/rest/health
 *     port: 8080
 *   initialDelaySeconds: 30
 *   periodSeconds: 10
 * readinessProbe:
 *   httpGet:
 *     path: /cargo-tracker/rest/health
 *     port: 8080
 *   initialDelaySeconds: 15
 *   periodSeconds: 5
 * </pre>
 */
@ApplicationScoped
@Path("/health")
public class HealthCheckResource {

  /**
   * Returns the health status of the application.
   *
   * @return HTTP 200 with JSON body {"status":"UP","timestamp":"..."} when healthy
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
