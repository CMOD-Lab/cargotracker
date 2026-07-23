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
 * <p>Provides a standard /rest/health HTTP GET endpoint returning JSON status response.
 * This endpoint is used by Kubernetes liveness and readiness probes in AKS deployments.
 *
 * <p>Example usage in Kubernetes deployment:
 * <pre>
 *   livenessProbe:
 *     httpGet:
 *       path: /cargo-tracker/rest/health
 *       port: 8080
 *   readinessProbe:
 *     httpGet:
 *       path: /cargo-tracker/rest/health
 *       port: 8080
 * </pre>
 */
@ApplicationScoped
@Path("/health")
public class HealthCheckEndpoint {

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
