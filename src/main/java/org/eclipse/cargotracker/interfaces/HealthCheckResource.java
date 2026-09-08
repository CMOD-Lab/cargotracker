package org.eclipse.cargotracker.interfaces;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

/**
 * Health check endpoint for containerization readiness.
 *
 * This endpoint is required for AKS liveness and readiness probes.
 * It exposes a simple HTTP GET /rest/health endpoint that returns
 * a JSON status response indicating the application is running.
 *
 * Added as part of mandatory containerization health check requirement.
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
