package org.eclipse.cargotracker.interfaces.booking.sse;

import java.util.logging.Level;
import java.util.logging.Logger;
import org.eclipse.cargotracker.domain.model.cargo.Cargo;
import org.eclipse.cargotracker.domain.model.cargo.RoutingStatus;
import org.eclipse.cargotracker.domain.model.cargo.TransportStatus;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;

/**
 * View adapter for displaying a cargo in a realtime tracking context.
 *
 * <p>Status label lookups are backed by Amazon ElastiCache for Redis with a TTL policy to ensure
 * controlled expiration and consistent label data across all application instances in the cloud
 * environment. The static in-memory {@code EnumMap} caches have been replaced with Redis-backed
 * lookups to eliminate unbounded memory growth and stale-data inconsistencies.
 */
public class RealtimeCargoTrackingViewAdapter {

  private static final Logger LOGGER =
      Logger.getLogger(RealtimeCargoTrackingViewAdapter.class.getName());

  /** Redis key prefix for routing-status label cache entries. */
  private static final String ROUTING_STATUS_KEY_PREFIX = "label:routing:";

  /** Redis key prefix for transport-status label cache entries. */
  private static final String TRANSPORT_STATUS_KEY_PREFIX = "label:transport:";

  /**
   * TTL in seconds for status-label cache entries (1 hour). Labels are application-level constants
   * that rarely change; a moderate TTL ensures stale entries are evicted without excessive
   * re-seeding overhead.
   */
  private static final int CACHE_TTL_SECONDS = 3600;

  /** Shared JedisPool backed by Amazon ElastiCache for Redis. */
  private static final JedisPool JEDIS_POOL;

  private final Cargo cargo;

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

    // Seed the Redis cache with the well-known status labels on first startup.
    seedStatusLabels();
  }

  /**
   * Populates the Redis cache with routing-status and transport-status labels. Uses SETNX semantics
   * so that existing entries (already seeded by another instance) are not overwritten, while the
   * TTL is always refreshed to prevent premature expiry.
   */
  private static void seedStatusLabels() {
    try (Jedis jedis = JEDIS_POOL.getResource()) {
      // Routing status labels
      seedLabel(jedis, ROUTING_STATUS_KEY_PREFIX + RoutingStatus.NOT_ROUTED.name(), "Not routed");
      seedLabel(jedis, ROUTING_STATUS_KEY_PREFIX + RoutingStatus.ROUTED.name(), "Routed");
      seedLabel(jedis, ROUTING_STATUS_KEY_PREFIX + RoutingStatus.MISROUTED.name(), "Misrouted");

      // Transport status labels
      seedLabel(
          jedis,
          TRANSPORT_STATUS_KEY_PREFIX + TransportStatus.NOT_RECEIVED.name(),
          "Not received");
      seedLabel(jedis, TRANSPORT_STATUS_KEY_PREFIX + TransportStatus.IN_PORT.name(), "In port");
      seedLabel(
          jedis,
          TRANSPORT_STATUS_KEY_PREFIX + TransportStatus.ONBOARD_CARRIER.name(),
          "Onboard carrier");
      seedLabel(jedis, TRANSPORT_STATUS_KEY_PREFIX + TransportStatus.CLAIMED.name(), "Claimed");
      seedLabel(jedis, TRANSPORT_STATUS_KEY_PREFIX + TransportStatus.UNKNOWN.name(), "Unknown");
    } catch (Exception e) {
      LOGGER.log(
          Level.SEVERE,
          "Failed to seed status labels in ElastiCache Redis. "
              + "Verify REDIS_HOST and REDIS_PORT environment variables.",
          e);
    }
  }

  /**
   * Writes a single label entry to Redis only if it does not already exist, then (re-)applies the
   * TTL to ensure the entry expires and is refreshed periodically.
   */
  private static void seedLabel(Jedis jedis, String key, String label) {
    jedis.setnx(key, label);
    jedis.expire(key, CACHE_TTL_SECONDS);
  }

  /**
   * Retrieves a cached label from Amazon ElastiCache for Redis.
   *
   * @param key the full Redis key for the label
   * @param fallback the value to return when the key is absent or Redis is unavailable
   * @return the cached label, or {@code fallback} if not found
   */
  private static String getLabel(String key, String fallback) {
    try (Jedis jedis = JEDIS_POOL.getResource()) {
      String value = jedis.get(key);
      return value != null ? value : fallback;
    } catch (Exception e) {
      LOGGER.log(
          Level.WARNING,
          "Failed to retrieve label for key '" + key + "' from ElastiCache Redis.",
          e);
      return fallback;
    }
  }

  public RealtimeCargoTrackingViewAdapter(Cargo cargo) {
    this.cargo = cargo;
  }

  public String getTrackingId() {
    return cargo.getTrackingId().getIdString();
  }

  public String getRoutingStatus() {
    RoutingStatus status = cargo.getDelivery().getRoutingStatus();
    return getLabel(ROUTING_STATUS_KEY_PREFIX + status.name(), status.toString());
  }

  public boolean isMisdirected() {
    return cargo.getDelivery().isMisdirected();
  }

  public String getTransportStatus() {
    TransportStatus status = cargo.getDelivery().getTransportStatus();
    return getLabel(TRANSPORT_STATUS_KEY_PREFIX + status.name(), status.toString());
  }

  public boolean isAtDestination() {
    return cargo.getDelivery().isUnloadedAtDestination();
  }

  public LocationViewAdapter getOrigin() {
    return new LocationViewAdapter(cargo.getOrigin());
  }

  public LocationViewAdapter getLastKnownLocation() {
    return new LocationViewAdapter(cargo.getDelivery().getLastKnownLocation());
  }

  public LocationViewAdapter getLocation() {
    return cargo.getDelivery().getTransportStatus() == TransportStatus.NOT_RECEIVED
        ? getOrigin()
        : getLastKnownLocation();
  }

  public String getStatusCode() {
    RoutingStatus routingStatus = cargo.getDelivery().getRoutingStatus();

    if (routingStatus == RoutingStatus.NOT_ROUTED || routingStatus == RoutingStatus.MISROUTED) {
      return routingStatus.toString();
    }

    if (cargo.getDelivery().isMisdirected()) {
      return "MISDIRECTED";
    }

    if (cargo.getDelivery().isUnloadedAtDestination()) {
      return "AT_DESTINATION";
    }

    return cargo.getDelivery().getTransportStatus().toString();
  }
}
