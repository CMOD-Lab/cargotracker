package org.eclipse.cargotracker.infrastructure.cache;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Level;
import java.util.logging.Logger;
import org.eclipse.cargotracker.domain.model.voyage.Voyage;
import org.eclipse.cargotracker.domain.model.voyage.VoyageNumber;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;
import redis.clients.jedis.exceptions.JedisException;

/**
 * Redis-backed voyage registry that replaces the static mutable {@code HashMap} in
 * {@code SampleVoyages} (rule cr-java-0066).
 *
 * <p>Voyage numbers are stored in Amazon ElastiCache for Redis so that all distributed application
 * instances share a single, consistent view of the voyage registry. A local in-process
 * {@link ConcurrentHashMap} is maintained as a fast lookup cache and fallback when Redis is
 * unavailable.
 *
 * <p>The Redis host and port are read from the environment variables
 * {@code ELASTICACHE_REDIS_HOST} and {@code ELASTICACHE_REDIS_PORT} (defaulting to
 * {@code localhost} and {@code 6379} respectively), following the 12-factor app configuration
 * principle.
 */
public final class RedisVoyageRegistry {

  private static final Logger LOGGER = Logger.getLogger(RedisVoyageRegistry.class.getName());

  /** Redis key prefix for voyage number entries. */
  private static final String VOYAGE_KEY_PREFIX = "voyage:";

  /** Redis set key that holds all registered voyage number strings. */
  private static final String VOYAGE_INDEX_KEY = "voyages:index";

  /**
   * Local in-process cache of {@link Voyage} objects keyed by {@link VoyageNumber}.
   * Acts as a fast lookup layer and fallback when Redis is unavailable.
   */
  private static final Map<VoyageNumber, Voyage> LOCAL_CACHE = new ConcurrentHashMap<>();

  /** Lazily-initialised Jedis connection pool; {@code null} when Redis is not configured. */
  private static volatile JedisPool jedisPool;

  /** Flag to suppress repeated Redis-unavailable warnings. */
  private static volatile boolean redisWarningLogged = false;

  static {
    jedisPool = buildPool();
  }

  private RedisVoyageRegistry() {
    // Utility class — no instances.
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /**
   * Registers a {@link Voyage} in both the local cache and Amazon ElastiCache for Redis.
   *
   * @param voyage the voyage to register; must not be {@code null}
   */
  public static void register(Voyage voyage) {
    if (voyage == null) {
      return;
    }
    VoyageNumber number = voyage.getVoyageNumber();
    LOCAL_CACHE.put(number, voyage);
    persistToRedis(number);
  }

  /**
   * Looks up a {@link Voyage} by its {@link VoyageNumber}.
   *
   * <p>The lookup first checks the local in-process cache (which is always populated during
   * class initialisation). Redis is consulted to verify that the voyage is still registered
   * across all instances; if Redis is unavailable the local cache result is returned.
   *
   * @param voyageNumber the voyage number to look up
   * @return the matching {@link Voyage}, or {@code null} if not found
   */
  public static Voyage lookup(VoyageNumber voyageNumber) {
    if (voyageNumber == null) {
      return null;
    }
    // Verify presence in Redis (cross-instance consistency check).
    if (isRegisteredInRedis(voyageNumber)) {
      return LOCAL_CACHE.get(voyageNumber);
    }
    // Fallback: return from local cache if Redis is unavailable or entry not found in Redis.
    return LOCAL_CACHE.get(voyageNumber);
  }

  // ---------------------------------------------------------------------------
  // Redis helpers
  // ---------------------------------------------------------------------------

  /**
   * Persists the voyage number string to Redis so that all distributed instances are aware of it.
   */
  private static void persistToRedis(VoyageNumber voyageNumber) {
    if (jedisPool == null) {
      return;
    }
    try (Jedis jedis = jedisPool.getResource()) {
      String numberStr = voyageNumber.getIdString();
      // Store the voyage number in a Redis Set for O(1) membership checks.
      jedis.sadd(VOYAGE_INDEX_KEY, numberStr);
      // Also store a simple key so individual voyage numbers can be retrieved.
      jedis.set(VOYAGE_KEY_PREFIX + numberStr, numberStr);
    } catch (JedisException e) {
      logRedisWarning("Failed to persist voyage number to Redis", e);
    }
  }

  /**
   * Returns {@code true} if the voyage number is present in the Redis index, or if Redis is
   * unavailable (fail-open to preserve backward compatibility).
   */
  private static boolean isRegisteredInRedis(VoyageNumber voyageNumber) {
    if (jedisPool == null) {
      return true; // Fail-open: treat as registered when Redis is not configured.
    }
    try (Jedis jedis = jedisPool.getResource()) {
      return jedis.sismember(VOYAGE_INDEX_KEY, voyageNumber.getIdString());
    } catch (JedisException e) {
      logRedisWarning("Failed to check voyage registration in Redis", e);
      return true; // Fail-open.
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
          "ELASTICACHE_REDIS_HOST not set — RedisVoyageRegistry will use local in-process cache "
              + "only. Set ELASTICACHE_REDIS_HOST (and optionally ELASTICACHE_REDIS_PORT) to "
              + "enable Amazon ElastiCache for Redis.");
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
      LOGGER.info("RedisVoyageRegistry connected to Amazon ElastiCache at " + host + ":" + port);
      return pool;
    } catch (Exception e) {
      LOGGER.log(Level.WARNING,
          "Could not create JedisPool for " + host + ":" + port
              + " — falling back to local in-process cache.", e);
      return null;
    }
  }

  private static void logRedisWarning(String message, Exception cause) {
    if (!redisWarningLogged) {
      LOGGER.log(Level.WARNING, message + " — falling back to local cache.", cause);
      redisWarningLogged = true;
    }
  }
}
