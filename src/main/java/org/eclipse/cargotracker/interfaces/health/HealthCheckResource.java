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
 * Provides liveness and readiness probes for GKE Autopilot deployments.
 *
 * <p>Endpoints:
 * <ul>
 *   <li>GET /rest/health - Overall health status</li>
 *   <li>GET /rest/health/live - Liveness probe</li>
 *   <li>GET /rest/health/ready - Readiness probe</li>
 * </ul>
 */
@ApplicationScoped
@Path("/health")
public class HealthCheckResource {

    /**
     * Overall health check endpoint.
     * Returns HTTP 200 with JSON status when the application is healthy.
     */
    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public Response health() {
        Map<String, Object> status = new LinkedHashMap<>();
        status.put("status", "UP");
        status.put("timestamp", Instant.now().toString());
        return Response.ok(status).build();
    }

    /**
     * Liveness probe - indicates whether the application is running.
     * Used by GKE Autopilot to determine if the container should be restarted.
     */
    @GET
    @Path("/live")
    @Produces(MediaType.APPLICATION_JSON)
    public Response liveness() {
        Map<String, Object> status = new LinkedHashMap<>();
        status.put("status", "UP");
        status.put("check", "liveness");
        status.put("timestamp", Instant.now().toString());
        return Response.ok(status).build();
    }

    /**
     * Readiness probe - indicates whether the application is ready to serve traffic.
     * Used by GKE Autopilot to determine if the container should receive requests.
     */
    @GET
    @Path("/ready")
    @Produces(MediaType.APPLICATION_JSON)
    public Response readiness() {
        Map<String, Object> status = new LinkedHashMap<>();
        status.put("status", "UP");
        status.put("check", "readiness");
        status.put("timestamp", Instant.now().toString());
        return Response.ok(status).build();
    }
}
