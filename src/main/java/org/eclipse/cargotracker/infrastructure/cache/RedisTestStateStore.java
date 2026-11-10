package org.eclipse.cargotracker.infrastructure.cache;

import java.util.concurrent.ConcurrentHashMap;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;
import redis.clients.jedis.exceptions.JedisException;

/**
 * Redis-backed key/value state store used to replace static mutable fields that previously held
 * shared state between ordered test methods (rule cr-java-0066).
 *
 * <p>In a distributed cloud environment each JVM instance maintains its own copy of static
 * variables, causing data inconsistency across test runners. This class externalises that shared
 * state to Amazon ElastiCache for Redis so that all instances read from and write to a single
 * authoritative source.
 *
 * <p>A local {@link ConcurrentHashMap} is maintained as a fast in-process fallback for
 * environments where Redis is not available (e.g., local developer machines or CI pipelines that
 * do not provision ElastiCache).
 *
 * <p>Configuration is read from the environment variables {@code ELASTICACHE_REDIS_HOST} and
 * {@code ELASTICACHE_REDIS_PORT}, following the 12-factor app principle.
 */
public final class RedisTestStateStore {

  private static final Logger LOGGER = Logger.getLogger(RedisTestStateStore.class.getName());

  /** TTL (seconds) for Redis keys — 1 hour is sufficient for a test run. */
  private static final int KEY_TTL_SECONDS = 3600;

  /** Namespace prefix derived from the test class name to avoid key collisions. */
  private final String namespace;

  /** Local in-process fallback map used when Redis is unavailable. */
  private final Map<String, String> localStore = new ConcurrentHashMap<>();

  /** Shared Jedis pool; {@code null} when Redis is not configured. */
  private static volatile JedisPool jedisPool;

  static {
    jedisPool = buildPool();
  }

  /**
   * Creates a new state store scoped to the given namespace (typically the test class name).
   *
   * @param namespace a non-null, non-empty namespace string
   */
  public RedisTestStateStore(String namespace) {
    if (namespace == null || namespace.isBlank()) {
      throw new IllegalArgumentException("namespace must not be null or blank");
    }
    this.namespace = namespace;
  }

  // ---------------------------------------------------------------------------
  // Write operations
  // ---------------------------------------------------------------------------

  /**
   * Stores a string value under the given key in Redis (and the local fallback map).
   *
   * @param key   the key; must not be {@code null}
   * @param value the value to store
   */
  public void putString(String key, String value) {
    localStore.put(key, value);
    if (jedisPool == null) {
      return;
    }
    try (Jedis jedis = jedisPool.getResource()) {
      jedis.setex(redisKey(key), KEY_TTL_SECONDS, value == null ? "" : value);
    } catch (JedisException e) {
      LOGGER.log(Level.WARNING, "Failed to write key '" + key + "' to Redis; using local store.", e);
    }
  }

  /**
   * Stores an integer value under the given key.
   *
   * @param key   the key; must not be {@code null}
   * @param value the integer value to store
   */
  public void putInt(String key, int value) {
    putString(key, Integer.toString(value));
  }

  // ---------------------------------------------------------------------------
  // Read operations
  // ---------------------------------------------------------------------------

  /**
   * Retrieves a string value by key. Redis is consulted first; the local fallback map is used
   * when Redis is unavailable or the key is not found in Redis.
   *
   * @param key the key; must not be {@code null}
   * @return the stored value, or {@code null} if not found
   */
  public String getString(String key) {
    if (jedisPool != null) {
      try (Jedis jedis = jedisPool.getResource()) {
        String value = jedis.get(redisKey(key));
        if (value != null) {
          return value.isEmpty() ? null : value;
        }
      } catch (JedisException e) {
        LOGGER.log(Level.WARNING,
            "Failed to read key '" + key + "' from Redis; falling back to local store.", e);
      }
    }
    return localStore.get(key);
  }

  /**
   * Retrieves an integer value by key.
   *
   * @param key          the key; must not be {@code null}
   * @param defaultValue value to return when the key is not found or cannot be parsed
   * @return the stored integer value, or {@code defaultValue}
   */
  public int getInt(String key, int defaultValue) {
    String raw = getString(key);
    if (raw == null) {
      return defaultValue;
    }
    try {
      return Integer.parseInt(raw.trim());
    } catch (NumberFormatException e) {
      LOGGER.warning("Cannot parse integer for key '" + key + "' value '" + raw + "'; returning default.");
      return defaultValue;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  private String redisKey(String key) {
    return "teststate:" + namespace + ":" + key;
  }

  private static JedisPool buildPool() {
    String host = System.getenv("ELASTICACHE_REDIS_HOST");
    if (host == null || host.isBlank()) {
      LOGGER.info(
          "ELASTICACHE_REDIS_HOST not set — RedisTestStateStore will use local in-process map. "
              + "Set ELASTICACHE_REDIS_HOST (and optionally ELASTICACHE_REDIS_PORT) to enable "
              + "Amazon ElastiCache for Redis.");
      return null;
    }
    String portStr = System.getenv("ELASTICACHE_REDIS_PORT");
    int port = 6379;
    if (portStr != null && !portStr.isBlank()) {
      try {
        port = Integer.parseInt(portStr.trim());
      } catch (NumberFormatException e) {
        LOGGER.warning("Invalid ELASTICACHE_REDIS_PORT '" + portStr + "'; using 6379.");
      }
    }
    JedisPoolConfig cfg = new JedisPoolConfig();
    cfg.setMaxTotal(8);
    cfg.setMaxIdle(4);
    cfg.setMinIdle(1);
    cfg.setTestOnBorrow(true);
    try {
      JedisPool pool = new JedisPool(cfg, host, port);
      LOGGER.info("RedisTestStateStore connected to Amazon ElastiCache at " + host + ":" + port);
      return pool;
    } catch (Exception e) {
      LOGGER.log(Level.WARNING,
          "Could not create JedisPool for " + host + ":" + port
              + " — falling back to local in-process map.", e);
      return null;
    }
  }
}
