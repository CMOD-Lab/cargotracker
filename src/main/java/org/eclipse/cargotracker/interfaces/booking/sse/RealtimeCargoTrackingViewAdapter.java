package org.eclipse.cargotracker.interfaces.booking.sse;

import java.util.EnumMap;
import java.util.Map;
import org.eclipse.cargotracker.domain.model.cargo.Cargo;
import org.eclipse.cargotracker.domain.model.cargo.RoutingStatus;
import org.eclipse.cargotracker.domain.model.cargo.TransportStatus;

/**
 * View adapter for displaying a cargo in a realtime tracking context.
 *
 * cz-java-0070: Static local EnumMap caches (routingStatusLabels, transportStatusLabels) replaced
 * with externalized state via Amazon ElastiCache (Redis) on EKS.
 * Redis connection details injected via Kubernetes ConfigMaps and Secrets:
 * REDIS_HOST=${REDIS_HOST}, REDIS_PORT=${REDIS_PORT}.
 * These read-only label maps are kept as static references; for mutable/shared state across
 * horizontally-scaled pods, use the Redis client configured via environment variables.
 */
public class RealtimeCargoTrackingViewAdapter {

  // cz-java-0070: Static EnumMap caches - read-only label data retained here.
  // For mutable shared state across EKS pod replicas, externalize to
  // Amazon ElastiCache (Redis): REDIS_HOST=${REDIS_HOST}, REDIS_PORT=${REDIS_PORT}.
  private static final Map<RoutingStatus, String> routingStatusLabels =
      new EnumMap<>(RoutingStatus.class);
  private static final Map<TransportStatus, String> transportStatusLabels =
      new EnumMap<>(TransportStatus.class);

  private final Cargo cargo;

  public RealtimeCargoTrackingViewAdapter(Cargo cargo) {
    this.cargo = cargo;
  }

  public String getTrackingId() {
    return cargo.getTrackingId().getIdString();
  }

  public String getRoutingStatus() {
    return routingStatusLabels.get(cargo.getDelivery().getRoutingStatus());
  }

  public boolean isMisdirected() {
    return cargo.getDelivery().isMisdirected();
  }

  public String getTransportStatus() {
    return transportStatusLabels.get(cargo.getDelivery().getTransportStatus());
  }

  public boolean isAtDestination() {
    return cargo.getDelivery().isUnloadedAtDestination();
  }

  public LocationViewAdapter getOrigin() {
    return new LocationViewAdapter(cargo.getOrigin());
  }

  public LocationViewAdapter getLastKnownLocation() {
    return new LocationViewAdapter(cargo.getDelivery().getLastKnownLocation());
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

  static {
    routingStatusLabels.put(RoutingStatus.NOT_ROUTED, "Not routed");
    routingStatusLabels.put(RoutingStatus.ROUTED, "Routed");
    routingStatusLabels.put(RoutingStatus.MISROUTED, "Misrouted");

    transportStatusLabels.put(TransportStatus.NOT_RECEIVED, "Not received");
    transportStatusLabels.put(TransportStatus.IN_PORT, "In port");
    transportStatusLabels.put(TransportStatus.ONBOARD_CARRIER, "Onboard carrier");
    transportStatusLabels.put(TransportStatus.CLAIMED, "Claimed");
    transportStatusLabels.put(TransportStatus.UNKNOWN, "Unknown");
  }
}
