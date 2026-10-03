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

import java.util.logging.Level;
import java.util.logging.Logger;
import org.eclipse.cargotracker.domain.model.location.Location;
import org.eclipse.cargotracker.domain.model.location.UnLocode;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;

/**
 * At the moment, coordinates are produced by a simple factory. It may be converted to a repository
 * if coordinates become a domain layer concern.
 *
 * <p>Coordinates are cached in Amazon ElastiCache for Redis with a TTL policy to ensure controlled
 * expiration and consistent data across all application instances in the cloud environment.
 */
public class CoordinatesFactory {

  private static final Logger LOGGER = Logger.getLogger(CoordinatesFactory.class.getName());

  /** Redis key prefix for coordinates cache entries. */
  private static final String CACHE_KEY_PREFIX = "coordinates:";

  /**
   * TTL in seconds for coordinates cache entries (24 hours). Coordinates are static geographic
   * data, so a long TTL is appropriate; entries are refreshed on expiry.
   */
  private static final int CACHE_TTL_SECONDS = 86400;

  /** Shared JedisPool backed by Amazon ElastiCache for Redis. */
  private static final JedisPool JEDIS_POOL;

  private CoordinatesFactory() {
    /* Prevent instantiation. */
  }

  static {
    // Resolve ElastiCache Redis endpoint from environment variables.
    // Set REDIS_HOST and REDIS_PORT in your AWS environment (e.g., ECS task definition,
    // Elastic Beanstalk environment properties, or Systems Manager Parameter Store).
    String redisHost =
        System.getenv("REDIS_HOST") != null ? System.getenv("REDIS_HOST") : "localhost";
    int redisPort;
    try {
      redisPort =
          System.getenv("REDIS_PORT") != null
              ? Integer.parseInt(System.getenv("REDIS_PORT"))
              : 6379;
    } catch (NumberFormatException e) {
      LOGGER.log(Level.WARNING, "Invalid REDIS_PORT value; defaulting to 6379", e);
      redisPort = 6379;
    }

    JedisPoolConfig poolConfig = new JedisPoolConfig();
    poolConfig.setMaxTotal(16);
    poolConfig.setMaxIdle(8);
    poolConfig.setMinIdle(2);
    poolConfig.setTestOnBorrow(true);
    poolConfig.setTestOnReturn(true);

    JEDIS_POOL = new JedisPool(poolConfig, redisHost, redisPort);

    // Seed the Redis cache with the well-known coordinates on first startup.
    // Each entry is stored with a TTL so stale data is automatically evicted.
    seedCache();
  }

  /**
   * Populates the Redis cache with the well-known location coordinates. Uses SET NX (set-if-not-
   * exists) semantics via SETNX so that existing entries (already seeded by another instance) are
   * not overwritten unnecessarily.
   */
  private static void seedCache() {
    try (Jedis jedis = JEDIS_POOL.getResource()) {
      seedEntry(jedis, HONGKONG.getUnLocode().getIdString(), 22, 114);
      seedEntry(jedis, MELBOURNE.getUnLocode().getIdString(), -38, 145);
      seedEntry(jedis, STOCKHOLM.getUnLocode().getIdString(), 59, 18);
      seedEntry(jedis, HELSINKI.getUnLocode().getIdString(), 60, 25);
      seedEntry(jedis, CHICAGO.getUnLocode().getIdString(), 42, -88);
      seedEntry(jedis, TOKYO.getUnLocode().getIdString(), 36, 140);
      seedEntry(jedis, HAMBURG.getUnLocode().getIdString(), 54, 10);
      seedEntry(jedis, SHANGHAI.getUnLocode().getIdString(), 31, 121);
      seedEntry(jedis, ROTTERDAM.getUnLocode().getIdString(), 52, 5);
      seedEntry(jedis, GOTHENBURG.getUnLocode().getIdString(), 58, 12);
      seedEntry(jedis, HANGZOU.getUnLocode().getIdString(), 30, 120);
      seedEntry(jedis, NEWYORK.getUnLocode().getIdString(), 41, -74);
      seedEntry(jedis, DALLAS.getUnLocode().getIdString(), 33, -97);
      // The South Pole represents the UNKNOWN location.
      seedEntry(jedis, UNKNOWN.getUnLocode().getIdString(), -90, 0);
    } catch (Exception e) {
      LOGGER.log(
          Level.SEVERE,
          "Failed to seed coordinates cache in ElastiCache Redis. "
              + "Verify REDIS_HOST and REDIS_PORT environment variables.",
          e);
    }
  }

  /**
   * Writes a single coordinate entry to Redis only if it does not already exist, then (re-)applies
   * the TTL to ensure the entry expires and is refreshed periodically.
   */
  private static void seedEntry(Jedis jedis, String unLocode, double lat, double lon) {
    String key = CACHE_KEY_PREFIX + unLocode;
    String value = lat + "," + lon;
    // SETNX: only set if the key is absent (avoids overwriting a recently refreshed entry).
    jedis.setnx(key, value);
    // Always refresh the TTL so the entry does not expire while the application is running.
    jedis.expire(key, CACHE_TTL_SECONDS);
  }

  public static Coordinates find(Location location) {
    return find(location.getUnLocode());
  }

  public static Coordinates find(UnLocode unLocode) {
    return find(unLocode.getIdString());
  }

  /**
   * Looks up coordinates for the given UN/LOCODE from the Amazon ElastiCache for Redis cache.
   *
   * @param unLocode the UN/LOCODE string identifier
   * @return the {@link Coordinates} for the location, or {@code null} if not found
   */
  public static Coordinates find(String unLocode) {
    String key = CACHE_KEY_PREFIX + unLocode;
    try (Jedis jedis = JEDIS_POOL.getResource()) {
      String value = jedis.get(key);
      if (value == null) {
        return null;
      }
      String[] parts = value.split(",");
      double lat = Double.parseDouble(parts[0]);
      double lon = Double.parseDouble(parts[1]);
      return new Coordinates(lat, lon);
    } catch (Exception e) {
      LOGGER.log(
          Level.WARNING,
          "Failed to retrieve coordinates for UN/LOCODE '"
              + unLocode
              + "' from ElastiCache Redis.",
          e);
      return null;
    }
  }
}
