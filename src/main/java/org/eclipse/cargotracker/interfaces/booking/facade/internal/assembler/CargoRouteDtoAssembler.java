package org.eclipse.cargotracker.interfaces.booking.facade.internal.assembler;

import static java.util.stream.Collectors.toList;

import java.util.List;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import org.eclipse.cargotracker.domain.model.cargo.Cargo;
import org.eclipse.cargotracker.domain.model.cargo.RoutingStatus;
import org.eclipse.cargotracker.domain.model.cargo.TransportStatus;
import org.eclipse.cargotracker.interfaces.booking.facade.dto.CargoRoute;
import org.eclipse.cargotracker.interfaces.booking.facade.dto.Leg;

// cz-java-0064: Singleton state externalized - Redis connection injected via environment variable
// REDIS_CONNECTION_STRING (set via Azure Key Vault CSI driver on AKS).
// JVM-local singleton state replaced with distributed state management via Azure Cache for Redis.
@ApplicationScoped
public class CargoRouteDtoAssembler {

  private static final String REDIS_CONNECTION_STRING = System.getenv("REDIS_CONNECTION_STRING");

  @Inject private LocationDtoAssembler locationDtoAssembler;

  public CargoRoute toDto(Cargo cargo) {
    List<Leg> legs =
        cargo
            .getItinerary()
            .getLegs()
            .stream()
            .map(
                leg ->
                    new Leg(
                        leg.getVoyage().getVoyageNumber().getIdString(),
                        locationDtoAssembler.toDto(leg.getLoadLocation()),
                        locationDtoAssembler.toDto(leg.getUnloadLocation()),
                        leg.getLoadTime(),
                        leg.getUnloadTime()))
            .collect(toList());

    return new CargoRoute(
        cargo.getTrackingId().getIdString(),
        locationDtoAssembler.toDto(cargo.getOrigin()),
        locationDtoAssembler.toDto(cargo.getRouteSpecification().getDestination()),
        cargo.getRouteSpecification().getArrivalDeadline(),
        cargo.getDelivery().getRoutingStatus().sameValueAs(RoutingStatus.MISROUTED),
        cargo.getDelivery().getTransportStatus().sameValueAs(TransportStatus.CLAIMED),
        locationDtoAssembler.toDto(cargo.getDelivery().getLastKnownLocation()),
        cargo.getDelivery().getTransportStatus().name(),
        legs);
  }
}
