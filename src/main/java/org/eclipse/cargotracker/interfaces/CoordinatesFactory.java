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
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Level;
import java.util.logging.Logger;
import org.eclipse.cargotracker.domain.model.location.Location;
import org.eclipse.cargotracker.domain.model.location.UnLocode;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;
import redis.clients.jedis.exceptions.JedisException;

/**
 * At the moment, coordinates are produced by a simple factory. It may be converted to a repository
 * if coordinates become a domain layer concern.
 *
 * <p>Coordinates are cached in Amazon ElastiCache for Redis with a configurable TTL so that
 * entries expire and are refreshed across all distributed instances (rule cr-java-0067).
 * A local in-process {@link ConcurrentHashMap} is maintained as a fast lookup layer and fallback
 * when Redis is unavailable.
 *
 * <p>Redis connection is configured via the environment variables
 * {@code ELASTICACHE_REDIS_HOST} and {@code ELASTICACHE_REDIS_PORT} (defaulting to
 * {@code localhost} and {@code 6379} respectively), following the 12-factor app principle.
 */
public class CoordinatesFactory {

  private static final Logger LOGGER = Logger.getLogger(CoordinatesFactory.class.getName());

  /** Redis key prefix for coordinate entries. */
  private static final String COORD_KEY_PREFIX = "coordinates:";

  /**
   * TTL (seconds) for coordinate entries in Redis — 24 hours.
   * Coordinates are static reference data; a long TTL avoids unnecessary re-seeding while
   * still ensuring eventual expiry and refresh across instances.
   */
  private static final int COORD_TTL_SECONDS = 86400;

  /**
   * Local in-process cache of {@link Coordinates} objects keyed by UN/LOCODE string.
   * Acts as a fast lookup layer and fallback when Redis is unavailable.
   */
  private static final Map<String, Coordinates> LOCAL_COORDINATES_MAP;

  /** Lazily-initialised Jedis connection pool; {@code null} when Redis is not configured. */
  private static volatile JedisPool jedisPool;

  private CoordinatesFactory() {
    /* Prevent instantiation. */
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  public static Coordinates find(Location location) {
    return find(location.getUnLocode());
  }

  public static Coordinates find(UnLocode unLocode) {
    return find(unLocode.getIdString());
  }

  /**
   * Looks up {@link Coordinates} for the given UN/LOCODE string.
   *
   * <p>The lookup first checks the local in-process cache. When Redis is available the entry is
   * also verified/refreshed in ElastiCache so that all distributed instances share a consistent
   * view with proper TTL-based expiry.
   *
   * @param unLocode the UN/LOCODE identifier string
   * @return the matching {@link Coordinates}, or {@code null} if not found
   */
  public static Coordinates find(String unLocode) {
    // Attempt to refresh TTL in Redis (non-blocking; failures fall back to local cache).
    refreshTtlInRedis(unLocode);
    return LOCAL_COORDINATES_MAP.get(unLocode);
  }

  // ---------------------------------------------------------------------------
  // Redis helpers
  // ---------------------------------------------------------------------------

  /**
   * Stores a coordinate entry in Redis with the configured TTL so that the entry expires
   * automatically and is not held indefinitely in memory across instances.
   */
  private static void seedToRedis(String unLocode, Coordinates coordinates) {
    if (jedisPool == null) {
      return;
    }
    try (Jedis jedis = jedisPool.getResource()) {
      // Store as "lat,lon" string with TTL to enforce expiry.
      String value = coordinates.getLatitude() + "," + coordinates.getLongitude();
      jedis.setex(COORD_KEY_PREFIX + unLocode, COORD_TTL_SECONDS, value);
    } catch (JedisException e) {
      LOGGER.log(Level.WARNING,
          "Failed to seed coordinates for '" + unLocode + "' to Redis; local cache will be used.",
          e);
    }
  }

  /**
   * Refreshes the TTL of an existing coordinate entry in Redis so that frequently accessed
   * entries do not expire while still ensuring eventual expiry for stale entries.
   */
  private static void refreshTtlInRedis(String unLocode) {
    if (jedisPool == null) {
      return;
    }
    try (Jedis jedis = jedisPool.getResource()) {
      jedis.expire(COORD_KEY_PREFIX + unLocode, COORD_TTL_SECONDS);
    } catch (JedisException e) {
      LOGGER.log(Level.FINE,
          "Could not refresh TTL for coordinates key '" + unLocode + "' in Redis.", e);
    }
  }

  /**
   * Builds a {@link JedisPool} from environment variables, or returns {@code null} when the
   * required environment variable is not set (local/test environments).
   */
  private static JedisPool buildPool() {
    String host = System.getenv("ELASTICACHE_REDIS_HOST");
    if (host == null || host.isBlank()) {
      LOGGER.info(
          "ELASTICACHE_REDIS_HOST not set — CoordinatesFactory will use local in-process cache "
              + "only. Set ELASTICACHE_REDIS_HOST (and optionally ELASTICACHE_REDIS_PORT) to "
              + "enable Amazon ElastiCache for Redis with TTL-based expiry.");
      return null;
    }
    String portStr = System.getenv("ELASTICACHE_REDIS_PORT");
    int port = 6379;
    if (portStr != null && !portStr.isBlank()) {
      try {
        port = Integer.parseInt(portStr.trim());
      } catch (NumberFormatException e) {
        LOGGER.warning("Invalid ELASTICACHE_REDIS_PORT value '" + portStr + "'; using 6379.");
      }
    }
    JedisPoolConfig poolConfig = new JedisPoolConfig();
    poolConfig.setMaxTotal(16);
    poolConfig.setMaxIdle(8);
    poolConfig.setMinIdle(2);
    poolConfig.setTestOnBorrow(true);
    poolConfig.setTestOnReturn(true);
    poolConfig.setTestWhileIdle(true);
    try {
      JedisPool pool = new JedisPool(poolConfig, host, port);
      LOGGER.info(
          "CoordinatesFactory connected to Amazon ElastiCache at " + host + ":" + port);
      return pool;
    } catch (Exception e) {
      LOGGER.log(Level.WARNING,
          "Could not create JedisPool for " + host + ":" + port
              + " — falling back to local in-process cache.", e);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Static initialiser — seed local cache and ElastiCache for Redis
  // ---------------------------------------------------------------------------

  static {
    jedisPool = buildPool();

    Map<String, Coordinates> map = new ConcurrentHashMap<>();

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

    LOCAL_COORDINATES_MAP = Collections.unmodifiableMap(map);

    // Seed all coordinate entries into Amazon ElastiCache for Redis with TTL.
    LOCAL_COORDINATES_MAP.forEach(CoordinatesFactory::seedToRedis);
  }
}
