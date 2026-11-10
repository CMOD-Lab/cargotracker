package org.eclipse.cargotracker.interfaces.booking.sse;

import java.util.EnumMap;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;
import org.eclipse.cargotracker.domain.model.cargo.Cargo;
import org.eclipse.cargotracker.domain.model.cargo.RoutingStatus;
import org.eclipse.cargotracker.domain.model.cargo.TransportStatus;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;
import redis.clients.jedis.exceptions.JedisException;

/**
 * View adapter for displaying a cargo in a realtime tracking context.
 *
 * <p>Status label mappings are cached in Amazon ElastiCache for Redis with a configurable TTL
 * (rule cr-java-0067). This replaces the previous unbounded static {@link EnumMap} fields that
 * had no expiration policy and could cause stale data inconsistencies across multiple instances.
 * A local in-process {@link EnumMap} is maintained as a fast lookup layer and fallback when
 * Redis is unavailable.
 *
 * <p>Redis connection is configured via the environment variables
 * {@code ELASTICACHE_REDIS_HOST} and {@code ELASTICACHE_REDIS_PORT} (defaulting to
 * {@code localhost} and {@code 6379} respectively), following the 12-factor app principle.
 */
public class RealtimeCargoTrackingViewAdapter {

  private static final Logger LOGGER =
      Logger.getLogger(RealtimeCargoTrackingViewAdapter.class.getName());

  // ---------------------------------------------------------------------------
  // Redis configuration
  // ---------------------------------------------------------------------------

  /** Redis key prefix for routing-status label entries. */
  private static final String ROUTING_LABEL_KEY_PREFIX = "label:routing:";

  /** Redis key prefix for transport-status label entries. */
  private static final String TRANSPORT_LABEL_KEY_PREFIX = "label:transport:";

  /**
   * TTL (seconds) for status-label entries in Redis — 1 hour.
   * Labels are static reference data; a moderate TTL ensures eventual expiry and refresh
   * across instances while avoiding unnecessary re-seeding on every request.
   */
  private static final int LABEL_TTL_SECONDS = 3600;

  /** Lazily-initialised Jedis connection pool; {@code null} when Redis is not configured. */
  private static volatile JedisPool jedisPool;

  // ---------------------------------------------------------------------------
  // Local in-process caches (fast lookup + fallback when Redis is unavailable)
  // ---------------------------------------------------------------------------

  private static final Map<RoutingStatus, String> routingStatusLabels =
      new EnumMap<>(RoutingStatus.class);
  private static final Map<TransportStatus, String> transportStatusLabels =
      new EnumMap<>(TransportStatus.class);

  // ---------------------------------------------------------------------------
  // Instance state
  // ---------------------------------------------------------------------------

  private final Cargo cargo;

  public RealtimeCargoTrackingViewAdapter(Cargo cargo) {
    this.cargo = cargo;
  }

  // ---------------------------------------------------------------------------
  // Public view methods
  // ---------------------------------------------------------------------------

  public String getTrackingId() {
    return cargo.getTrackingId().getIdString();
  }

  public String getRoutingStatus() {
    return getRoutingLabel(cargo.getDelivery().getRoutingStatus());
  }

  public boolean isMisdirected() {
    return cargo.getDelivery().isMisdirected();
  }

  public String getTransportStatus() {
    return getTransportLabel(cargo.getDelivery().getTransportStatus());
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

  // ---------------------------------------------------------------------------
  // Redis-backed label lookup helpers
  // ---------------------------------------------------------------------------

  /**
   * Returns the display label for the given {@link RoutingStatus}.
   *
   * <p>Checks Redis first (refreshing the TTL on hit) so that all distributed instances share
   * a consistent, TTL-bounded view. Falls back to the local in-process cache when Redis is
   * unavailable.
   */
  private static String getRoutingLabel(RoutingStatus status) {
    if (jedisPool != null) {
      try (Jedis jedis = jedisPool.getResource()) {
        String key = ROUTING_LABEL_KEY_PREFIX + status.name();
        String value = jedis.get(key);
        if (value != null) {
          jedis.expire(key, LABEL_TTL_SECONDS); // Refresh TTL on access.
          return value;
        }
      } catch (JedisException e) {
        LOGGER.log(Level.FINE, "Redis lookup failed for routing label; using local cache.", e);
      }
    }
    return routingStatusLabels.get(status);
  }

  /**
   * Returns the display label for the given {@link TransportStatus}.
   *
   * <p>Checks Redis first (refreshing the TTL on hit) so that all distributed instances share
   * a consistent, TTL-bounded view. Falls back to the local in-process cache when Redis is
   * unavailable.
   */
  private static String getTransportLabel(TransportStatus status) {
    if (jedisPool != null) {
      try (Jedis jedis = jedisPool.getResource()) {
        String key = TRANSPORT_LABEL_KEY_PREFIX + status.name();
        String value = jedis.get(key);
        if (value != null) {
          jedis.expire(key, LABEL_TTL_SECONDS); // Refresh TTL on access.
          return value;
        }
      } catch (JedisException e) {
        LOGGER.log(Level.FINE, "Redis lookup failed for transport label; using local cache.", e);
      }
    }
    return transportStatusLabels.get(status);
  }

  // ---------------------------------------------------------------------------
  // Redis pool builder
  // ---------------------------------------------------------------------------

  /**
   * Builds a {@link JedisPool} from environment variables, or returns {@code null} when the
   * required environment variable is not set (local/test environments).
   */
  private static JedisPool buildPool() {
    String host = System.getenv("ELASTICACHE_REDIS_HOST");
    if (host == null || host.isBlank()) {
      LOGGER.info(
          "ELASTICACHE_REDIS_HOST not set — RealtimeCargoTrackingViewAdapter will use local "
              + "in-process label maps only. Set ELASTICACHE_REDIS_HOST (and optionally "
              + "ELASTICACHE_REDIS_PORT) to enable Amazon ElastiCache for Redis with TTL-based "
              + "expiry.");
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
          "RealtimeCargoTrackingViewAdapter connected to Amazon ElastiCache at "
              + host + ":" + port);
      return pool;
    } catch (Exception e) {
      LOGGER.log(Level.WARNING,
          "Could not create JedisPool for " + host + ":" + port
              + " — falling back to local in-process label maps.", e);
      return null;
    }
  }

  /**
   * Seeds a label entry into Redis with the configured TTL.
   */
  private static void seedLabelToRedis(String keyPrefix, String statusName, String label) {
    if (jedisPool == null) {
      return;
    }
    try (Jedis jedis = jedisPool.getResource()) {
      jedis.setex(keyPrefix + statusName, LABEL_TTL_SECONDS, label);
    } catch (JedisException e) {
      LOGGER.log(Level.WARNING,
          "Failed to seed label '" + statusName + "' to Redis; local cache will be used.", e);
    }
  }

  // ---------------------------------------------------------------------------
  // Static initialiser — seed local caches and ElastiCache for Redis with TTL
  // ---------------------------------------------------------------------------

  static {
    jedisPool = buildPool();

    // Populate local in-process caches.
    routingStatusLabels.put(RoutingStatus.NOT_ROUTED, "Not routed");
    routingStatusLabels.put(RoutingStatus.ROUTED, "Routed");
    routingStatusLabels.put(RoutingStatus.MISROUTED, "Misrouted");

    transportStatusLabels.put(TransportStatus.NOT_RECEIVED, "Not received");
    transportStatusLabels.put(TransportStatus.IN_PORT, "In port");
    transportStatusLabels.put(TransportStatus.ONBOARD_CARRIER, "Onboard carrier");
    transportStatusLabels.put(TransportStatus.CLAIMED, "Claimed");
    transportStatusLabels.put(TransportStatus.UNKNOWN, "Unknown");

    // Seed all label entries into Amazon ElastiCache for Redis with TTL.
    routingStatusLabels.forEach(
        (status, label) ->
            seedLabelToRedis(ROUTING_LABEL_KEY_PREFIX, status.name(), label));
    transportStatusLabels.forEach(
        (status, label) ->
            seedLabelToRedis(TRANSPORT_LABEL_KEY_PREFIX, status.name(), label));
  }
}
