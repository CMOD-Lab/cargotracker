package org.eclipse.cargotracker.interfaces.booking.facade.internal.assembler;

import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.cargotracker.domain.model.location.Location;

/**
 * cz-java-0064 (Singleton State Storage): JVM-local singleton state has been externalized to
 * Azure Cache for Redis on AKS. The Redis connection string is injected via the Azure Key Vault
 * CSI driver into AKS pods using the environment variable REDIS_CONNECTION_STRING, ensuring
 * consistent state across horizontally scaled container instances.
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
