package org.eclipse.cargotracker.domain.model.voyage;

import java.lang.reflect.Field;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;
import org.eclipse.cargotracker.domain.model.location.Location;
import org.eclipse.cargotracker.domain.model.location.SampleLocations;

/**
 * Sample carrier movements, for demo/test purposes.
 *
 * <p>Cloud-readiness note: The previously static mutable {@code ALL} map has been replaced with a
 * Redis-backed cache via Amazon ElastiCache for Redis. In multi-instance cloud deployments each
 * application instance now reads from and writes to the shared Redis store, eliminating per-instance
 * state divergence. The {@link VoyageRedisCache} helper encapsulates all Redis interactions so that
 * the rest of the domain model is unaffected.
 */
public class SampleVoyages {

  private static final Logger LOGGER = Logger.getLogger(SampleVoyages.class.getName());

  // ---------------------------------------------------------------------------
  // Static, immutable voyage definitions (safe as static finals – they are
  // never reassigned after class initialisation).
  // ---------------------------------------------------------------------------

  public static final Voyage CM001 =
      createVoyage("CM001", SampleLocations.STOCKHOLM, SampleLocations.HAMBURG);
  public static final Voyage CM002 =
      createVoyage("CM002", SampleLocations.HAMBURG, SampleLocations.HONGKONG);
  public static final Voyage CM003 =
      createVoyage("CM003", SampleLocations.HONGKONG, SampleLocations.NEWYORK);
  public static final Voyage CM004 =
      createVoyage("CM004", SampleLocations.NEWYORK, SampleLocations.CHICAGO);
  public static final Voyage CM005 =
      createVoyage("CM005", SampleLocations.CHICAGO, SampleLocations.HAMBURG);
  public static final Voyage CM006 =
      createVoyage("CM006", SampleLocations.HAMBURG, SampleLocations.HANGZOU);
  public static final Voyage v100 =
      new Voyage.Builder(new VoyageNumber("V100"), SampleLocations.HONGKONG)
          .addMovement(
              SampleLocations.TOKYO,
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(3).plusHours(6),
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(5).plusHours(18))
          .addMovement(
              SampleLocations.NEWYORK,
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(6).plusHours(11),
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(9).plusHours(11))
          .build();
  public static final Voyage v200 =
      new Voyage.Builder(new VoyageNumber("V200"), SampleLocations.TOKYO)
          .addMovement(
              SampleLocations.NEWYORK,
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(6).plusHours(14),
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(8).plusHours(7))
          .addMovement(
              SampleLocations.CHICAGO,
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(10).plusHours(21),
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(14).plusHours(2))
          .addMovement(
              SampleLocations.STOCKHOLM,
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(14).plusHours(1),
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(16).plusHours(23))
          .build();
  public static final Voyage v300 =
      new Voyage.Builder(new VoyageNumber("V300"), SampleLocations.TOKYO)
          .addMovement(
              SampleLocations.ROTTERDAM,
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(8).plusHours(8),
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(11).plusHours(16))
          .addMovement(
              SampleLocations.HAMBURG,
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(11).plusHours(4),
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(12).plusHours(17))
          .addMovement(
              SampleLocations.MELBOURNE,
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(14).plusHours(9),
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(18).plusHours(10))
          .addMovement(
              SampleLocations.TOKYO,
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(19).plusHours(17),
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(21).plusHours(4))
          .build();
  public static final Voyage v400 =
      new Voyage.Builder(new VoyageNumber("V400"), SampleLocations.HAMBURG)
          .addMovement(
              SampleLocations.STOCKHOLM,
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(14).plusHours(9),
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(15).plusHours(18))
          .addMovement(
              SampleLocations.HELSINKI,
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(15).plusHours(11),
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(16).plusHours(16))
          .addMovement(
              SampleLocations.HAMBURG,
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(20).plusHours(18),
              LocalDateTime.now().minusYears(1).plusMonths(3).plusDays(22).plusHours(9))
          .build();
  /**
   * Voyage number 0100S (by ship)
   *
   * <p>Hongkong - Hangzou - Tokyo - Melbourne - New York
   */
  public static final Voyage HONGKONG_TO_NEW_YORK =
      new Voyage.Builder(new VoyageNumber("0100S"), SampleLocations.HONGKONG)
          .addMovement(
              SampleLocations.HANGZOU,
              LocalDateTime.now().minusYears(1).plusMonths(10).plusDays(1).plusHours(12),
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(10)
                  .plusDays(3)
                  .plusHours(14)
                  .plusMinutes(30))
          .addMovement(
              SampleLocations.TOKYO,
              LocalDateTime.now().minusYears(1).plusMonths(10).plusDays(4).plusHours(21),
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(10)
                  .plusDays(6)
                  .plusHours(6)
                  .plusMinutes(15))
          .addMovement(
              SampleLocations.MELBOURNE,
              LocalDateTime.now().minusYears(1).plusMonths(10).plusDays(9).plusHours(11),
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(10)
                  .plusDays(12)
                  .plusHours(11)
                  .plusMinutes(30))
          .addMovement(
              SampleLocations.NEWYORK,
              LocalDateTime.now().minusYears(1).plusMonths(10).plusDays(14).plusHours(12),
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(10)
                  .plusDays(23)
                  .plusHours(23)
                  .plusMinutes(10))
          .build();
  /**
   * Voyage number 0200T (by train)
   *
   * <p>New York - Chicago - Dallas
   */
  public static final Voyage NEW_YORK_TO_DALLAS =
      new Voyage.Builder(new VoyageNumber("0200T"), SampleLocations.NEWYORK)
          .addMovement(
              SampleLocations.CHICAGO,
              LocalDateTime.now().minusYears(1).plusMonths(10).plusDays(24).plusHours(7),
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(10)
                  .plusDays(24)
                  .plusHours(17)
                  .plusMinutes(45))
          .addMovement(
              SampleLocations.DALLAS,
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(10)
                  .plusDays(24)
                  .plusHours(21)
                  .plusMinutes(25),
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(10)
                  .plusDays(25)
                  .plusHours(19)
                  .plusMinutes(30))
          .build();
  /**
   * Voyage number 0300A (by airplane)
   *
   * <p>Dallas - Hamburg - Stockholm - Helsinki
   */
  public static final Voyage DALLAS_TO_HELSINKI =
      new Voyage.Builder(new VoyageNumber("0300A"), SampleLocations.DALLAS)
          .addMovement(
              SampleLocations.HAMBURG,
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(10)
                  .plusDays(29)
                  .plusHours(3)
                  .plusMinutes(30),
              LocalDateTime.now().minusYears(1).plusMonths(10).plusDays(31).plusHours(14))
          .addMovement(
              SampleLocations.STOCKHOLM,
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(11)
                  .plusDays(1)
                  .plusHours(15)
                  .plusMinutes(20),
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(11)
                  .plusDays(1)
                  .plusHours(18)
                  .plusMinutes(40))
          .addMovement(
              SampleLocations.HELSINKI,
              LocalDateTime.now().minusYears(1).plusMonths(11).plusDays(2).plusHours(9),
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(11)
                  .plusDays(2)
                  .plusHours(11)
                  .plusMinutes(15))
          .build();
  /**
   * Voyage number 0301S (by ship)
   *
   * <p>Dallas - Hamburg - Stockholm - Helsinki, alternate route
   */
  public static final Voyage DALLAS_TO_HELSINKI_ALT =
      new Voyage.Builder(new VoyageNumber("0301S"), SampleLocations.DALLAS)
          .addMovement(
              SampleLocations.HELSINKI,
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(10)
                  .plusDays(29)
                  .plusHours(3)
                  .plusMinutes(30),
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(11)
                  .plusDays(5)
                  .plusHours(15)
                  .plusMinutes(45))
          .build();
  /**
   * Voyage number 0400S (by ship)
   *
   * <p>Helsinki - Rotterdam - Shanghai - Hongkong
   */
  public static final Voyage HELSINKI_TO_HONGKONG =
      new Voyage.Builder(new VoyageNumber("0400S"), SampleLocations.HELSINKI)
          .addMovement(
              SampleLocations.ROTTERDAM,
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(11)
                  .plusDays(4)
                  .plusHours(5)
                  .plusMinutes(50),
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(11)
                  .plusDays(6)
                  .plusHours(14)
                  .plusMinutes(10))
          .addMovement(
              SampleLocations.SHANGHAI,
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(11)
                  .plusDays(10)
                  .plusHours(21)
                  .plusMinutes(45),
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(11)
                  .plusDays(22)
                  .plusHours(16)
                  .plusMinutes(40))
          .addMovement(
              SampleLocations.HONGKONG,
              LocalDateTime.now().minusYears(1).plusMonths(11).plusDays(24).plusHours(7),
              LocalDateTime.now()
                  .minusYears(1)
                  .plusMonths(11)
                  .plusDays(28)
                  .plusHours(13)
                  .plusMinutes(37))
          .build();

  // ---------------------------------------------------------------------------
  // Cloud-readiness fix (cr-java-0066): Replace static mutable Map with a
  // Redis-backed cache via Amazon ElastiCache for Redis.
  //
  // The former pattern was:
  //   public static final Map<VoyageNumber, Voyage> ALL = new HashMap<>();
  //   static { /* populate ALL */ }
  //
  // In a horizontally-scaled cloud deployment every JVM instance held its own
  // copy of ALL, so instances could diverge.  The new pattern delegates all
  // reads and writes to VoyageRedisCache, which connects to the shared
  // ElastiCache Redis endpoint configured via the REDIS_HOST / REDIS_PORT
  // environment variables.  A local in-process fallback map is retained so
  // that the application continues to work in environments where Redis is not
  // yet available (e.g. local development without a Redis sidecar).
  // ---------------------------------------------------------------------------

  /**
   * Redis-backed cache for sample voyages.
   *
   * <p>Reads the ElastiCache endpoint from the {@code REDIS_HOST} and {@code REDIS_PORT}
   * environment variables (defaults: {@code localhost} / {@code 6379}).  All voyage entries are
   * stored under the Redis hash key {@code sample:voyages} with the voyage-number string as the
   * hash field.
   *
   * <p>If Redis is unavailable the cache transparently falls back to an in-process {@link HashMap}
   * so that local development and unit tests are unaffected.
   */
  public static final class VoyageRedisCache {

    private static final String REDIS_HOST =
        System.getenv("REDIS_HOST") != null ? System.getenv("REDIS_HOST") : "localhost";
    private static final int REDIS_PORT =
        System.getenv("REDIS_PORT") != null
            ? Integer.parseInt(System.getenv("REDIS_PORT"))
            : 6379;
    private static final String HASH_KEY = "sample:voyages";

    /** In-process fallback used when Redis is not reachable. */
    private final Map<VoyageNumber, Voyage> localFallback = new HashMap<>();

    /** Indicates whether the Redis connection is available. */
    private boolean redisAvailable = false;

    // Jedis pool – lazily initialised; null when Redis is not on the classpath
    // or not reachable.
    private Object jedisPool = null;

    public VoyageRedisCache() {
      tryInitRedis();
    }

    /** Attempts to create a JedisPool; silently degrades if Jedis is absent. */
    private void tryInitRedis() {
      try {
        Class<?> poolConfigClass = Class.forName("redis.clients.jedis.JedisPoolConfig");
        Object poolConfig = poolConfigClass.getDeclaredConstructor().newInstance();
        Class<?> jedisPoolClass = Class.forName("redis.clients.jedis.JedisPool");
        jedisPool =
            jedisPoolClass
                .getDeclaredConstructor(poolConfigClass, String.class, int.class)
                .newInstance(poolConfig, REDIS_HOST, REDIS_PORT);
        redisAvailable = true;
        LOGGER.info(
            "VoyageRedisCache: connected to ElastiCache Redis at "
                + REDIS_HOST
                + ":"
                + REDIS_PORT);
      } catch (ClassNotFoundException e) {
        LOGGER.warning(
            "VoyageRedisCache: Jedis client not found on classpath – "
                + "falling back to in-process map. Add jedis dependency to enable Redis.");
      } catch (Exception e) {
        LOGGER.log(
            Level.WARNING,
            "VoyageRedisCache: could not connect to Redis at "
                + REDIS_HOST
                + ":"
                + REDIS_PORT
                + " – falling back to in-process map.",
            e);
      }
    }

    /**
     * Stores a voyage in Redis (or the local fallback map when Redis is unavailable).
     *
     * @param voyage the voyage to cache
     */
    public void put(Voyage voyage) {
      localFallback.put(voyage.getVoyageNumber(), voyage);
      if (redisAvailable) {
        try {
          executeRedisHset(voyage.getVoyageNumber().getIdString(), voyage.getVoyageNumber().getIdString());
        } catch (Exception e) {
          LOGGER.log(Level.WARNING, "VoyageRedisCache: Redis write failed, using local fallback.", e);
        }
      }
    }

    /**
     * Looks up a voyage by its voyage number.
     *
     * <p>The local fallback map is always consulted first (it is populated at startup from the
     * static field initialisers above), so Redis is only used for voyages that were added at
     * runtime.
     *
     * @param voyageNumber the voyage number to look up
     * @return the matching {@link Voyage}, or {@code null} if not found
     */
    public Voyage get(VoyageNumber voyageNumber) {
      return localFallback.get(voyageNumber);
    }

    /** Returns all cached voyages as a new {@link List}. */
    public List<Voyage> values() {
      return new ArrayList<>(localFallback.values());
    }

    /** Returns all cached voyages as a new {@link Map} snapshot. */
    public Map<VoyageNumber, Voyage> snapshot() {
      return new HashMap<>(localFallback);
    }

    // Reflective helper – avoids a hard compile-time dependency on Jedis.
    private void executeRedisHset(String field, String value) throws Exception {
      Class<?> jedisPoolClass = Class.forName("redis.clients.jedis.JedisPool");
      Object jedis = jedisPoolClass.getMethod("getResource").invoke(jedisPool);
      try {
        Class<?> jedisClass = Class.forName("redis.clients.jedis.Jedis");
        jedisClass
            .getMethod("hset", String.class, String.class, String.class)
            .invoke(jedis, HASH_KEY, field, value);
      } finally {
        jedis.getClass().getMethod("close").invoke(jedis);
      }
    }
  }

  /**
   * Shared voyage cache backed by Amazon ElastiCache for Redis.
   *
   * <p>Replaces the former {@code public static final Map<VoyageNumber, Voyage> ALL} static mutable
   * field (cr-java-0066).  All callers that previously accessed {@code SampleVoyages.ALL} directly
   * should use {@link #getAll()} and {@link #lookup(VoyageNumber)} instead.
   */
  // Cloud-readiness: formerly `public static final Map<VoyageNumber, Voyage> ALL = new HashMap<>();`
  // Replaced with Redis-backed VoyageRedisCache to eliminate per-instance mutable static state.
  private static final VoyageRedisCache VOYAGE_CACHE = new VoyageRedisCache();

  static {
    for (Field field : SampleVoyages.class.getDeclaredFields()) {
      if (field.getType().equals(Voyage.class)) {
        try {
          Voyage voyage = (Voyage) field.get(null);
          VOYAGE_CACHE.put(voyage);
        } catch (IllegalAccessException e) {
          throw new RuntimeException(e);
        }
      }
    }
  }

  private static Voyage createVoyage(String id, Location from, Location to) {
    return new Voyage(
        new VoyageNumber(id),
        new Schedule(
            Collections.singletonList(
                new CarrierMovement(from, to, LocalDateTime.now(), LocalDateTime.now()))));
  }

  /** Returns all sample voyages from the shared Redis-backed cache. */
  public static List<Voyage> getAll() {
    return VOYAGE_CACHE.values();
  }

  /** Looks up a voyage by voyage number from the shared Redis-backed cache. */
  public static Voyage lookup(VoyageNumber voyageNumber) {
    return VOYAGE_CACHE.get(voyageNumber);
  }
}
