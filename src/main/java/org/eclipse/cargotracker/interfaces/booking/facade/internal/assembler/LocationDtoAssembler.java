package org.eclipse.cargotracker.interfaces.booking.facade.internal.assembler;

import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.cargotracker.domain.model.location.Location;

/**
 * Containerization Note (blocker-14 / cz-java-0064): This class uses CDI @ApplicationScoped
 * instead of EJB @Singleton to avoid JVM-level singleton state that causes inconsistencies when
 * scaling containers horizontally on GKE Autopilot. Any shared/cached state should be stored in
 * Google Cloud Memorystore (Redis), with connection details injected via Workload Identity and
 * Secret Manager.
 */
@ApplicationScoped
public class LocationDtoAssembler {

  public org.eclipse.cargotracker.interfaces.booking.facade.dto.Location toDto(Location location) {
    return new org.eclipse.cargotracker.interfaces.booking.facade.dto.Location(
        location.getUnLocode().getIdString(), location.getName());
  }

  public List<org.eclipse.cargotracker.interfaces.booking.facade.dto.Location> toDtoList(
      List<Location> allLocations) {
    List<org.eclipse.cargotracker.interfaces.booking.facade.dto.Location> dtoList =
        allLocations
            .stream()
            .map(this::toDto)
            .sorted(
                Comparator.comparing(
                    org.eclipse.cargotracker.interfaces.booking.facade.dto.Location::getUnLocode))
            .collect(Collectors.toList());
    return dtoList;
  }
}
