package org.eclipse.cargotracker.interfaces.health;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import org.eclipse.cargotracker.infrastructure.cache.RedisStateManager;

/**
 * Health check endpoint for container liveness and readiness probes.
 *
 * <p>Exposes {@code GET /rest/health} returning a JSON status response.
 * This endpoint is required for containerization on EKS (health-check-endpoint).
 *
 * <p>Checks:
 * <ul>
 *   <li>Application status (always UP if the JVM is running)</li>
 *   <li>Redis/ElastiCache connectivity (via {@link RedisStateManager})</li>
 * </ul>
 */
@ApplicationScoped
@Path("/health")
public class HealthCheckEndpoint {

    private static final String STATUS_UP = "UP";
    private static final String STATUS_DOWN = "DOWN";

    @Inject
    private RedisStateManager redisStateManager;

    /**
     * Returns the overall health status of the application.
     *
     * @return HTTP 200 with {@code {"status":"UP",...}} when healthy,
     *         HTTP 503 with {@code {"status":"DOWN",...}} when unhealthy.
     */
    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public Response health() {
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("status", STATUS_UP);
        response.put("timestamp", Instant.now().toString());

        Map<String, Object> checks = new LinkedHashMap<>();

        // Application liveness check
        checks.put("application", STATUS_UP);

        // Redis / ElastiCache connectivity check
        String redisStatus = checkRedis();
        checks.put("redis", redisStatus);

        response.put("checks", checks);

        boolean healthy = STATUS_UP.equals(redisStatus);
        if (!healthy) {
            response.put("status", STATUS_DOWN);
            return Response.status(Response.Status.SERVICE_UNAVAILABLE)
                    .entity(response)
                    .build();
        }

        return Response.ok(response).build();
    }

    private String checkRedis() {
        try {
            // A lightweight existence check to verify Redis connectivity
            redisStateManager.exists("health:ping");
            return STATUS_UP;
        } catch (Exception e) {
            return STATUS_DOWN;
        }
    }
}
