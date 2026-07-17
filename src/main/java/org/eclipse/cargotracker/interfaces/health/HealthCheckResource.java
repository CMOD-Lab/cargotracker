package org.eclipse.cargotracker.interfaces.health;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

/**
 * Health check endpoint for containerization readiness.
 * Provides a simple liveness probe for AKS pod health monitoring.
 * Accessible at: GET /rest/health
 */
@ApplicationScoped
@Path("/health")
public class HealthCheckResource {

  @GET
  @Produces(MediaType.APPLICATION_JSON)
  public Response health() {
    return Response.ok("{\"status\":\"UP\",\"application\":\"cargo-tracker\"}").build();
  }
}
