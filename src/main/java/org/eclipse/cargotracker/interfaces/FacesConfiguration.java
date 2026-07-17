// cz-java-0064: @ApplicationScoped bean - singleton state storage identified.
// For horizontal scaling on GKE Autopilot, externalize any shared state to
// Google Cloud Memorystore (Redis) injecting connection via REDIS_HOST env variable.
public class FacesConfiguration {}
