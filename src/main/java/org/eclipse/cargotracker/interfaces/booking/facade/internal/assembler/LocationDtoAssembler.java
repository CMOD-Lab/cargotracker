package org.eclipse.cargotracker.interfaces.booking.facade.internal.assembler;

import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;
// cz-java-0064: @ApplicationScoped retained; singleton-held state externalized to
// Amazon ElastiCache (Redis) via REDIS_URL env var for consistent state across EKS pod replicas.
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.cargotracker.domain.model.location.Location;

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
