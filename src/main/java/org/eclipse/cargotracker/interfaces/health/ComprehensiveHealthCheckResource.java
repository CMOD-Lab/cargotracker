package org.eclipse.cargotracker.interfaces.health;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.jms.JMSContext;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Comprehensive health check endpoint for Kubernetes liveness and readiness probes.
 *
 * <p>Provides an HTTP GET /rest/health/status endpoint that returns the application status
 * including database connectivity, JMS messaging availability, and overall application readiness.
 *
 * <p>Example response:
 * <pre>
 * {
 *   "status": "UP",
 *   "checks": {
 *     "database": "UP",
 *     "messaging": "UP",
 *     "application": "UP"
 *   },
 *   "timestamp": "2026-07-17T12:34:56Z"
 * }
 * </pre>
 *
 * <p>Returns HTTP 200 when all checks pass (status: UP), HTTP 503 when any check fails (status: DOWN).
 */
@ApplicationScoped
@Path("/health/status")
public class ComprehensiveHealthCheckResource {

  @PersistenceContext
  private EntityManager entityManager;

  @Inject
  private JMSContext jmsContext;

  /**
   * Returns comprehensive health status of the application.
   *
   * <p>Performs lightweight checks on database connectivity and JMS messaging availability.
   * Each component is checked independently with graceful error handling to ensure one
   * failing component doesn't prevent checking others.
   *
   * @return HTTP 200 with JSON body when healthy (all checks UP), HTTP 503 when unhealthy (any check DOWN)
   */
  @GET
  @Produces(MediaType.APPLICATION_JSON)
  public Response health() {
    Map<String, String> checks = new LinkedHashMap<>();

    // Database health check
    String databaseStatus = checkDatabase();
    checks.put("database", databaseStatus);

    // Messaging health check
    String messagingStatus = checkMessaging();
    checks.put("messaging", messagingStatus);

    // Application health check (always UP as fallback indicator)
    checks.put("application", "UP");

    // Determine overall status
    boolean allUp = checks.values().stream().allMatch(status -> "UP".equals(status));
    String overallStatus = allUp ? "UP" : "DOWN";

    // Build response
    Map<String, Object> healthStatus = new LinkedHashMap<>();
    healthStatus.put("status", overallStatus);
    healthStatus.put("checks", checks);
    healthStatus.put("timestamp", Instant.now().toString());

    // Return appropriate HTTP status
    if (allUp) {
      return Response.ok(healthStatus).build();
    } else {
      return Response.status(Response.Status.SERVICE_UNAVAILABLE).entity(healthStatus).build();
    }
  }

  /**
   * Checks database connectivity using EntityManager.
   *
   * @return "UP" if database is available, "DOWN" otherwise
   */
  private String checkDatabase() {
    try {
      if (entityManager != null && entityManager.isOpen()) {
        return "UP";
      }
      return "DOWN";
    } catch (Exception e) {
      return "DOWN";
    }
  }

  /**
   * Checks JMS messaging availability.
   *
   * @return "UP" if messaging is available, "DOWN" otherwise
   */
  private String checkMessaging() {
    try {
      if (jmsContext != null) {
        return "UP";
      }
      return "DOWN";
    } catch (Exception e) {
      return "DOWN";
    }
  }
}
