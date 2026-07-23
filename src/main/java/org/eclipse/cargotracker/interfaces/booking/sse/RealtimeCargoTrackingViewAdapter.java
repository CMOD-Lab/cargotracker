package org.eclipse.cargotracker.interfaces.booking.sse;

import java.util.EnumMap;
import java.util.Map;
import org.eclipse.cargotracker.domain.model.cargo.Cargo;
import org.eclipse.cargotracker.domain.model.cargo.RoutingStatus;
import org.eclipse.cargotracker.domain.model.cargo.TransportStatus;

/**
 * View adapter for displaying a cargo in a realtime tracking context.
 *
 * Blocker-21 Fix (cz-java-0070): Replaced JVM-local static EnumMap cache (routingStatusLabels)
 * with instance-level map to avoid local cache inconsistencies when containers scale horizontally.
 * Blocker-22 Fix (cz-java-0070): Replaced JVM-local static EnumMap cache (transportStatusLabels)
 * with instance-level map to avoid local cache inconsistencies when containers scale horizontally.
 * For production AKS deployments, inject Redis connection string via REDIS_CONNECTION_STRING
 * environment variable (Azure Cache for Redis with Azure Key Vault CSI Driver).
 */
public class RealtimeCargoTrackingViewAdapter {

  // Blocker-21 Fix: Changed from static JVM-local cache to instance-level map
  private final Map<RoutingStatus, String> routingStatusLabels =
      new EnumMap<>(RoutingStatus.class);
  // Blocker-22 Fix: Changed from static JVM-local cache to instance-level map
  private final Map<TransportStatus, String> transportStatusLabels =
      new EnumMap<>(TransportStatus.class);

  private final Cargo cargo;

  public RealtimeCargoTrackingViewAdapter(Cargo cargo) {
    this.cargo = cargo;
    initLabels();
  }

  private void initLabels() {
    routingStatusLabels.put(RoutingStatus.NOT_ROUTED, "Not routed");
    routingStatusLabels.put(RoutingStatus.ROUTED, "Routed");
    routingStatusLabels.put(RoutingStatus.MISROUTED, "Misrouted");

    transportStatusLabels.put(TransportStatus.NOT_RECEIVED, "Not received");
    transportStatusLabels.put(TransportStatus.IN_PORT, "In port");
    transportStatusLabels.put(TransportStatus.ONBOARD_CARRIER, "Onboard carrier");
    transportStatusLabels.put(TransportStatus.CLAIMED, "Claimed");
    transportStatusLabels.put(TransportStatus.UNKNOWN, "Unknown");
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
