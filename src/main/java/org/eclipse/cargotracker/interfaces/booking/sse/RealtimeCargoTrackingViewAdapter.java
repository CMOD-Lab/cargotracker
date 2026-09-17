package org.eclipse.cargotracker.interfaces.booking.sse;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.cargotracker.domain.model.cargo.Cargo;
import org.eclipse.cargotracker.domain.model.cargo.RoutingStatus;
import org.eclipse.cargotracker.domain.model.cargo.TransportStatus;
import org.eclipse.cargotracker.interfaces.CoordinatesFactory;
import org.eclipse.cargotracker.infrastructure.cache.RedisStateManager;

/**
 * View adapter for displaying a cargo in a realtime tracking context.
 *
 * <p>Status label lookups are backed by Amazon ElastiCache (Redis) via {@link RedisStateManager}
 * so that all EKS pod replicas share a single consistent data store instead of relying on
 * local in-process {@code EnumMap} caches (cz-java-0070).
 */
@ApplicationScoped
public class RealtimeCargoTrackingViewAdapter {

  /** Redis key prefix for routing-status labels. */
  private static final String ROUTING_LABEL_PREFIX = "label:routing:";

  /** Redis key prefix for transport-status labels. */
  private static final String TRANSPORT_LABEL_PREFIX = "label:transport:";

  @Inject
  private RedisStateManager redisStateManager;

  @Inject
  private CoordinatesFactory coordinatesFactory;

  private Cargo cargo;

  /** CDI no-arg constructor. */
  public RealtimeCargoTrackingViewAdapter() {}

  public RealtimeCargoTrackingViewAdapter(Cargo cargo, RedisStateManager redisStateManager,
      CoordinatesFactory coordinatesFactory) {
    this.cargo = cargo;
    this.redisStateManager = redisStateManager;
    this.coordinatesFactory = coordinatesFactory;
  }

  /**
   * Initialises the status-label entries in Redis if they are not already present.
   * This replaces the former static {@code EnumMap} local caches (cz-java-0070).
   */
  @jakarta.annotation.PostConstruct
  public void init() {
    // Routing status labels
    setLabelIfAbsent(ROUTING_LABEL_PREFIX + RoutingStatus.NOT_ROUTED.name(), "Not routed");
    setLabelIfAbsent(ROUTING_LABEL_PREFIX + RoutingStatus.ROUTED.name(), "Routed");
    setLabelIfAbsent(ROUTING_LABEL_PREFIX + RoutingStatus.MISROUTED.name(), "Misrouted");

    // Transport status labels
    setLabelIfAbsent(TRANSPORT_LABEL_PREFIX + TransportStatus.NOT_RECEIVED.name(), "Not received");
    setLabelIfAbsent(TRANSPORT_LABEL_PREFIX + TransportStatus.IN_PORT.name(), "In port");
    setLabelIfAbsent(TRANSPORT_LABEL_PREFIX + TransportStatus.ONBOARD_CARRIER.name(), "Onboard carrier");
    setLabelIfAbsent(TRANSPORT_LABEL_PREFIX + TransportStatus.CLAIMED.name(), "Claimed");
    setLabelIfAbsent(TRANSPORT_LABEL_PREFIX + TransportStatus.UNKNOWN.name(), "Unknown");
  }

  public void setCargo(Cargo cargo) {
    this.cargo = cargo;
  }

  public String getTrackingId() {
    return cargo.getTrackingId().getIdString();
  }

  public String getRoutingStatus() {
    return redisStateManager.get(ROUTING_LABEL_PREFIX + cargo.getDelivery().getRoutingStatus().name());
  }

  public boolean isMisdirected() {
    return cargo.getDelivery().isMisdirected();
  }

  public String getTransportStatus() {
    return redisStateManager.get(TRANSPORT_LABEL_PREFIX + cargo.getDelivery().getTransportStatus().name());
  }

  public boolean isAtDestination() {
    return cargo.getDelivery().isUnloadedAtDestination();
  }

  public LocationViewAdapter getOrigin() {
    return new LocationViewAdapter(cargo.getOrigin(), coordinatesFactory);
  }

  public LocationViewAdapter getLastKnownLocation() {
    return new LocationViewAdapter(cargo.getDelivery().getLastKnownLocation(), coordinatesFactory);
  }

  public LocationViewAdapter getLocation() {
    return cargo.getDelivery().getTransportStatus() == TransportStatus.NOT_RECEIVED
        ? getOrigin()
        : getLastKnownLocation();
  }

  public String getStatusCode() {
    RoutingStatus routingStatus = cargo.getDelivery().getRoutingStatus();

    if (routingStatus == RoutingStatus.NOT_ROUTED || routingStatus == RoutingStatus.MISROUTED) {
      return routingStatus.toString();
    }

    if (cargo.getDelivery().isMisdirected()) {
      return "MISDIRECTED";
    }

    if (cargo.getDelivery().isUnloadedAtDestination()) {
      return "AT_DESTINATION";
    }

    return cargo.getDelivery().getTransportStatus().toString();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  private void setLabelIfAbsent(String key, String label) {
    if (redisStateManager.get(key) == null) {
      redisStateManager.set(key, label, 0);
    }
  }
}
