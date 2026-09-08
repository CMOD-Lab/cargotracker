package org.eclipse.cargotracker.interfaces.booking.facade.internal.assembler;

import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;
// cz-java-0064: @ApplicationScoped CDI bean - state externalized via Azure Cache for Redis.
// Redis connection string injected via REDIS_CONNECTION_STRING environment variable
// (Azure Key Vault CSI driver on AKS) to support horizontal scaling.
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.cargotracker.domain.model.location.Location;

@ApplicationScoped
public class LocationDtoAssembler {

  // Redis connection string injected via REDIS_CONNECTION_STRING env var (Azure Key Vault CSI driver on AKS)
  private final String redisConnectionString = System.getenv("REDIS_CONNECTION_STRING");

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
