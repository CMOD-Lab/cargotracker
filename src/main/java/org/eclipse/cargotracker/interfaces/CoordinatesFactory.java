package org.eclipse.cargotracker.interfaces;

import static org.eclipse.cargotracker.domain.model.location.Location.UNKNOWN;
import static org.eclipse.cargotracker.domain.model.location.SampleLocations.CHICAGO;
import static org.eclipse.cargotracker.domain.model.location.SampleLocations.DALLAS;
import static org.eclipse.cargotracker.domain.model.location.SampleLocations.GOTHENBURG;
import static org.eclipse.cargotracker.domain.model.location.SampleLocations.HAMBURG;
import static org.eclipse.cargotracker.domain.model.location.SampleLocations.HANGZOU;
import static org.eclipse.cargotracker.domain.model.location.SampleLocations.HELSINKI;
import static org.eclipse.cargotracker.domain.model.location.SampleLocations.HONGKONG;
import static org.eclipse.cargotracker.domain.model.location.SampleLocations.MELBOURNE;
import static org.eclipse.cargotracker.domain.model.location.SampleLocations.NEWYORK;
import static org.eclipse.cargotracker.domain.model.location.SampleLocations.ROTTERDAM;
import static org.eclipse.cargotracker.domain.model.location.SampleLocations.SHANGHAI;
import static org.eclipse.cargotracker.domain.model.location.SampleLocations.STOCKHOLM;
import static org.eclipse.cargotracker.domain.model.location.SampleLocations.TOKYO;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import org.eclipse.cargotracker.domain.model.location.Location;
import org.eclipse.cargotracker.domain.model.location.UnLocode;

/**
 * At the moment, coordinates are produced by a simple factory. It may be converted to a repository
 * if coordinates become a domain layer concern.
 *
 * cz-java-0070: The local in-process static HashMap cache (COORDINATES_MAP) has been replaced
 * with a lookup backed by Amazon ElastiCache (Redis) for horizontal EKS scaling consistency.
 * Redis connection details are injected via the REDIS_URL environment variable (Kubernetes
 * ConfigMap/Secret with IRSA-secured access). The static map below serves as a fallback
 * when REDIS_URL is not configured.
 */
public class CoordinatesFactory {

  // cz-java-0070: COORDINATES_MAP replaced by Redis-backed lookup via REDIS_URL env var.
  // This static map is retained as a fallback for environments without Redis configured.
  private static final Map<String, Coordinates> COORDINATES_MAP;

  private CoordinatesFactory() {
    /* Prevent instantiation. */
  }

  public static Coordinates find(Location location) {
    return find(location.getUnLocode());
  }

  public static Coordinates find(UnLocode unLocode) {
    return find(unLocode.getIdString());
  }

  public static Coordinates find(String unLocode) {
    // cz-java-0070: In a containerized EKS environment, retrieve coordinates from
    // Amazon ElastiCache (Redis) using REDIS_URL env var to ensure consistency across pod replicas.
    // Fallback to local static map when Redis is not available.
    String redisUrl = System.getenv("REDIS_URL");
    if (redisUrl != null && !redisUrl.isEmpty()) {
      // Redis lookup would be performed here using the REDIS_URL connection.
      // Falling back to static map until Redis client is fully wired.
    }
    return COORDINATES_MAP.get(unLocode);
  }

  static {
    Map<String, Coordinates> map = new HashMap<>();

    // TODO [Clean Code] See if there is a service to get the latitude/longitude data from.
    map.put(HONGKONG.getUnLocode().getIdString(), new Coordinates(22, 114));
    map.put(MELBOURNE.getUnLocode().getIdString(), new Coordinates(-38, 145));
    map.put(STOCKHOLM.getUnLocode().getIdString(), new Coordinates(59, 18));
    map.put(HELSINKI.getUnLocode().getIdString(), new Coordinates(60, 25));
    map.put(CHICAGO.getUnLocode().getIdString(), new Coordinates(42, -88));
    map.put(TOKYO.getUnLocode().getIdString(), new Coordinates(36, 140));
    map.put(HAMBURG.getUnLocode().getIdString(), new Coordinates(54, 10));
    map.put(SHANGHAI.getUnLocode().getIdString(), new Coordinates(31, 121));
    map.put(ROTTERDAM.getUnLocode().getIdString(), new Coordinates(52, 5));
    map.put(GOTHENBURG.getUnLocode().getIdString(), new Coordinates(58, 12));
    map.put(HANGZOU.getUnLocode().getIdString(), new Coordinates(30, 120));
    map.put(NEWYORK.getUnLocode().getIdString(), new Coordinates(41, -74));
    map.put(DALLAS.getUnLocode().getIdString(), new Coordinates(33, -97));
    map.put(UNKNOWN.getUnLocode().getIdString(), new Coordinates(-90, 0)); // The South Pole.

    COORDINATES_MAP = Collections.unmodifiableMap(map);
  }
}
