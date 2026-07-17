package org.eclipse.cargotracker.interfaces;

// Containerization (blocker-9 / cz-java-0064): Singleton state storage identified.
// Migrate JVM singleton state to Google Cloud Memorystore (Redis) on GKE Autopilot.
// Inject Redis connection details via environment variables:
//   REDIS_HOST = System.getenv("REDIS_HOST")
//   REDIS_PORT = System.getenv("REDIS_PORT")
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.faces.annotation.FacesConfig;

/** Jakarta Faces configuration. * */
@FacesConfig()
@ApplicationScoped
public class FacesConfiguration {}
