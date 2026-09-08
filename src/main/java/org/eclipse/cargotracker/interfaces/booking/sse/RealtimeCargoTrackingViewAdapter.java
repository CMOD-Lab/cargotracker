package org.eclipse.cargotracker.interfaces.booking.sse;

import java.util.EnumMap;
import java.util.Map;
import org.eclipse.cargotracker.domain.model.cargo.Cargo;
import org.eclipse.cargotracker.domain.model.cargo.RoutingStatus;
import org.eclipse.cargotracker.domain.model.cargo.TransportStatus;

/**
 * View adapter for displaying a cargo in a realtime tracking context.
 *
 * Blocker blocker-21 (cz-java-0070): Replaced static local cache (routingStatusLabels) with
 * instance-level map to avoid shared in-process state that does not replicate across container
 * replicas. For distributed caching across pods, use Google Cloud Memorystore (Redis) on GKE,
 * injecting connection details via environment variables: REDIS_HOST, REDIS_PORT.
 *
 * Blocker blocker-22 (cz-java-0070): Replaced static local cache (transportStatusLabels) with
 * instance-level map to avoid shared in-process state that does not replicate across container
 * replicas. For distributed caching across pods, use Google Cloud Memorystore (Redis) on GKE,
 * injecting connection details via environment variables: REDIS_HOST, REDIS_PORT.
 */
public class RealtimeCargoTrackingViewAdapter {

  // Instance-level maps replace static local caches to avoid horizontal scaling inconsistencies.
  private final Map<RoutingStatus, String> routingStatusLabels;
  private final Map<TransportStatus, String> transportStatusLabels;

  private final Cargo cargo;

  public RealtimeCargoTrackingViewAdapter(Cargo cargo) {
    this.cargo = cargo;

    this.routingStatusLabels = new EnumMap<>(RoutingStatus.class);
    this.routingStatusLabels.put(RoutingStatus.NOT_ROUTED, "Not routed");
    this.routingStatusLabels.put(RoutingStatus.ROUTED, "Routed");
    this.routingStatusLabels.put(RoutingStatus.MISROUTED, "Misrouted");

    this.transportStatusLabels = new EnumMap<>(TransportStatus.class);
    this.transportStatusLabels.put(TransportStatus.NOT_RECEIVED, "Not received");
    this.transportStatusLabels.put(TransportStatus.IN_PORT, "In port");
    this.transportStatusLabels.put(TransportStatus.ONBOARD_CARRIER, "Onboard carrier");
    this.transportStatusLabels.put(TransportStatus.CLAIMED, "Claimed");
    this.transportStatusLabels.put(TransportStatus.UNKNOWN, "Unknown");
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
}
