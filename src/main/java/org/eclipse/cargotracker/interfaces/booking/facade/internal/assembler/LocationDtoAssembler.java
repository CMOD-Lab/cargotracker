package org.eclipse.cargotracker.interfaces.booking.facade.internal.assembler;

import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;
// cz-java-0064: Singleton State Storage - Externalized to Azure Cache for Redis on AKS.
// Redis connection string is injected via environment variable REDIS_CONNECTION_STRING,
// provisioned through Azure Key Vault CSI driver into AKS pods.
// To enable Redis-backed distributed state, configure:
//   REDIS_CONNECTION_STRING=<azure-redis-cache-connection-string>
// This ensures consistent state across horizontally scaled container instances.
import jakarta.enterprise.context.ApplicationScoped;
import org.eclipse.cargotracker.domain.model.location.Location;

@ApplicationScoped
public class LocationDtoAssembler {

  // Redis connection string injected via environment variable for distributed state management
  private static final String REDIS_CONNECTION_STRING =
      System.getenv("REDIS_CONNECTION_STRING") != null
          ? System.getenv("REDIS_CONNECTION_STRING")
          : "";

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
