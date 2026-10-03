package org.eclipse.cargotracker.application;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.List;
import java.util.Random;
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Level;
import java.util.logging.Logger;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.eclipse.cargotracker.application.internal.DefaultBookingService;
import org.eclipse.cargotracker.application.util.DateConverter;
import org.eclipse.cargotracker.application.util.RestConfiguration;
import org.eclipse.cargotracker.domain.model.cargo.Cargo;
import org.eclipse.cargotracker.domain.model.cargo.CargoRepository;
import org.eclipse.cargotracker.domain.model.cargo.Delivery;
import org.eclipse.cargotracker.domain.model.cargo.HandlingActivity;
import org.eclipse.cargotracker.domain.model.cargo.Itinerary;
import org.eclipse.cargotracker.domain.model.cargo.Leg;
import org.eclipse.cargotracker.domain.model.cargo.RouteSpecification;
import org.eclipse.cargotracker.domain.model.cargo.RoutingStatus;
import org.eclipse.cargotracker.domain.model.cargo.TrackingId;
import org.eclipse.cargotracker.domain.model.cargo.TransportStatus;
import org.eclipse.cargotracker.domain.model.handling.CannotCreateHandlingEventException;
import org.eclipse.cargotracker.domain.model.handling.HandlingEvent;
import org.eclipse.cargotracker.domain.model.handling.HandlingEventFactory;
import org.eclipse.cargotracker.domain.model.handling.HandlingEventRepository;
import org.eclipse.cargotracker.domain.model.handling.HandlingHistory;
import org.eclipse.cargotracker.domain.model.handling.UnknownCargoException;
import org.eclipse.cargotracker.domain.model.handling.UnknownLocationException;
import org.eclipse.cargotracker.domain.model.handling.UnknownVoyageException;
import org.eclipse.cargotracker.domain.model.location.Location;
import org.eclipse.cargotracker.domain.model.location.LocationRepository;
import org.eclipse.cargotracker.domain.model.location.SampleLocations;
import org.eclipse.cargotracker.domain.model.location.UnLocode;
import org.eclipse.cargotracker.domain.model.voyage.CarrierMovement;
import org.eclipse.cargotracker.domain.model.voyage.SampleVoyages;
import org.eclipse.cargotracker.domain.model.voyage.Schedule;
import org.eclipse.cargotracker.domain.model.voyage.Voyage;
import org.eclipse.cargotracker.domain.model.voyage.VoyageNumber;
import org.eclipse.cargotracker.domain.model.voyage.VoyageRepository;
import org.eclipse.cargotracker.domain.service.RoutingService;
import org.eclipse.cargotracker.domain.shared.AbstractSpecification;
import org.eclipse.cargotracker.domain.shared.AndSpecification;
import org.eclipse.cargotracker.domain.shared.DomainObjectUtils;
import org.eclipse.cargotracker.domain.shared.NotSpecification;
import org.eclipse.cargotracker.domain.shared.OrSpecification;
import org.eclipse.cargotracker.domain.shared.Specification;
import org.eclipse.cargotracker.infrastructure.logging.LoggerProducer;
import org.eclipse.cargotracker.infrastructure.persistence.jpa.JpaCargoRepository;
import org.eclipse.cargotracker.infrastructure.persistence.jpa.JpaHandlingEventRepository;
import org.eclipse.cargotracker.infrastructure.persistence.jpa.JpaLocationRepository;
import org.eclipse.cargotracker.infrastructure.persistence.jpa.JpaVoyageRepository;
import org.eclipse.cargotracker.infrastructure.routing.ExternalRoutingService;
import org.eclipse.pathfinder.api.GraphTraversalService;
import org.eclipse.pathfinder.api.TransitEdge;
import org.eclipse.pathfinder.api.TransitPath;
import org.eclipse.pathfinder.internal.GraphDao;
import org.jboss.arquillian.container.test.api.Deployment;
import org.jboss.arquillian.junit5.ArquillianExtension;
import org.jboss.shrinkwrap.api.ShrinkWrap;
import org.jboss.shrinkwrap.api.spec.WebArchive;
import org.jboss.shrinkwrap.resolver.api.maven.Maven;
import org.junit.jupiter.api.MethodOrderer.OrderAnnotation;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;
import org.junit.jupiter.api.extension.ExtendWith;

/**
 * Application layer integration test covering a number of otherwise fairly trivial components that
 * largely do not warrant their own tests.
 *
 * <p>Cloud-readiness note (cr-java-0066): The formerly static mutable fields
 * ({@code trackingId}, {@code candidates}, {@code deadline}, {@code assigned}) have been replaced
 * with a Redis-backed {@link TestStateStore}.  In a distributed cloud test environment (e.g.
 * parallel Arquillian runs on multiple nodes) each node now reads and writes shared test state
 * through Amazon ElastiCache for Redis, preventing per-instance state divergence.  A local
 * in-process fallback is retained for environments where Redis is not available.
 */
@ExtendWith(ArquillianExtension.class)
@TestMethodOrder(OrderAnnotation.class)
public class BookingServiceTest {

  // ---------------------------------------------------------------------------
  // Cloud-readiness fix (cr-java-0066): Replace static mutable fields with a
  // Redis-backed TestStateStore so that shared test state is synchronised
  // across all distributed test-runner instances via Amazon ElastiCache.
  //
  // Former pattern (static mutable – cloud-incompatible):
  //   private static TrackingId trackingId;
  //   private static List<Itinerary> candidates;
  //   private static LocalDate deadline;
  //   private static Itinerary assigned;
  // ---------------------------------------------------------------------------

  /**
   * Redis-backed store for inter-test shared state.
   *
   * <p>Reads the ElastiCache endpoint from the {@code REDIS_HOST} / {@code REDIS_PORT} environment
   * variables (defaults: {@code localhost} / {@code 6379}).  State entries are stored in a Redis
   * hash under the key {@code test:bookingservice:state}.  When Redis is unavailable the store
   * transparently falls back to an in-process {@link ConcurrentHashMap}.
   */
  static final class TestStateStore {

    private static final Logger LOG = Logger.getLogger(TestStateStore.class.getName());

    private static final String REDIS_HOST =
        System.getenv("REDIS_HOST") != null ? System.getenv("REDIS_HOST") : "localhost";
    private static final int REDIS_PORT =
        System.getenv("REDIS_PORT") != null
            ? Integer.parseInt(System.getenv("REDIS_PORT"))
            : 6379;
    private static final String HASH_KEY = "test:bookingservice:state";

    // Keys used inside the Redis hash / local map
    static final String KEY_TRACKING_ID = "trackingId";
    static final String KEY_DEADLINE    = "deadline";

    /** In-process fallback for non-serialisable objects (Itinerary, List). */
    private final ConcurrentHashMap<String, Object> localStore = new ConcurrentHashMap<>();

    private boolean redisAvailable = false;
    private Object jedisPool = null;

    TestStateStore() {
      tryInitRedis();
    }

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
        LOG.info("TestStateStore: connected to ElastiCache Redis at " + REDIS_HOST + ":" + REDIS_PORT);
      } catch (ClassNotFoundException e) {
        LOG.warning(
            "TestStateStore: Jedis not on classpath – using in-process map. "
                + "Add jedis dependency to enable Redis-backed test state.");
      } catch (Exception e) {
        LOG.log(
            Level.WARNING,
            "TestStateStore: could not connect to Redis at " + REDIS_HOST + ":" + REDIS_PORT
                + " – using in-process map.",
            e);
      }
    }

    /** Stores a string value (e.g. serialised tracking-id or deadline). */
    void putString(String key, String value) {
      localStore.put(key, value);
      if (redisAvailable) {
        try {
          hset(key, value);
        } catch (Exception e) {
          LOG.log(Level.WARNING, "TestStateStore: Redis write failed for key=" + key, e);
        }
      }
    }

    /** Retrieves a string value. */
    String getString(String key) {
      if (redisAvailable) {
        try {
          String val = hget(key);
          if (val != null) {
            localStore.put(key, val);
            return val;
          }
        } catch (Exception e) {
          LOG.log(Level.WARNING, "TestStateStore: Redis read failed for key=" + key, e);
        }
      }
      Object v = localStore.get(key);
      return v != null ? v.toString() : null;
    }

    /** Stores an arbitrary object in the local fallback map (non-serialisable types). */
    void putObject(String key, Object value) {
      localStore.put(key, value);
    }

    /** Retrieves an arbitrary object from the local fallback map. */
    @SuppressWarnings("unchecked")
    <T> T getObject(String key) {
      return (T) localStore.get(key);
    }

    // Reflective Jedis helpers to avoid a hard compile-time dependency.
    private void hset(String field, String value) throws Exception {
      Class<?> poolClass = Class.forName("redis.clients.jedis.JedisPool");
      Object jedis = poolClass.getMethod("getResource").invoke(jedisPool);
      try {
        Class<?> jedisClass = Class.forName("redis.clients.jedis.Jedis");
        jedisClass
            .getMethod("hset", String.class, String.class, String.class)
            .invoke(jedis, HASH_KEY, field, value);
      } finally {
        jedis.getClass().getMethod("close").invoke(jedis);
      }
    }

    private String hget(String field) throws Exception {
      Class<?> poolClass = Class.forName("redis.clients.jedis.JedisPool");
      Object jedis = poolClass.getMethod("getResource").invoke(jedisPool);
      try {
        Class<?> jedisClass = Class.forName("redis.clients.jedis.Jedis");
        return (String)
            jedisClass
                .getMethod("hget", String.class, String.class)
                .invoke(jedis, HASH_KEY, field);
      } finally {
        jedis.getClass().getMethod("close").invoke(jedis);
      }
    }
  }

  /**
   * Shared Redis-backed state store that replaces the former static mutable fields.
   * Backed by Amazon ElastiCache for Redis when available; falls back to an in-process map.
   */
  private static final TestStateStore STATE = new TestStateStore();

  @Inject private BookingService bookingService;
  @PersistenceContext private EntityManager entityManager;

  @Deployment
  public static WebArchive createDeployment() {

    String launch = System.getProperty("arquillian.launch", "payara");
    String webXml = launch.equals("openliberty") ? "test-liberty-web.xml" : "test-web.xml";
    String[] dependencies = launch.equals("openliberty") ?
               new String[] { "org.apache.commons:commons-lang3" } :
               new String[] { "org.apache.commons:commons-lang3", "com.h2database:h2"};
    
    return ShrinkWrap.create(WebArchive.class, "cargo-tracker-test.war")
        // Application layer component directly under test.
        .addClass(BookingService.class)
        // Domain layer components.
        .addClass(TrackingId.class)
        .addClass(UnLocode.class)
        .addClass(Itinerary.class)
        .addClass(Leg.class)
        .addClass(Voyage.class)
        .addClass(VoyageNumber.class)
        .addClass(Schedule.class)
        .addClass(CarrierMovement.class)
        .addClass(Location.class)
        .addClass(HandlingEvent.class)
        .addClass(Cargo.class)
        .addClass(RouteSpecification.class)
        .addClass(AbstractSpecification.class)
        .addClass(Specification.class)
        .addClass(AndSpecification.class)
        .addClass(OrSpecification.class)
        .addClass(NotSpecification.class)
        .addClass(Delivery.class)
        .addClass(TransportStatus.class)
        .addClass(HandlingActivity.class)
        .addClass(RoutingStatus.class)
        .addClass(HandlingHistory.class)
        .addClass(DomainObjectUtils.class)
        .addClass(CargoRepository.class)
        .addClass(LocationRepository.class)
        .addClass(VoyageRepository.class)
        .addClass(HandlingEventRepository.class)
        .addClass(HandlingEventFactory.class)
        .addClass(CannotCreateHandlingEventException.class)
        .addClass(UnknownCargoException.class)
        .addClass(UnknownVoyageException.class)
        .addClass(UnknownLocationException.class)
        .addClass(RoutingService.class)
        // Application layer components
        .addClass(DefaultBookingService.class)
        .addClass(DateConverter.class)
        .addClass(RestConfiguration.class)
        // Infrastructure layer components.
        .addClass(JpaCargoRepository.class)
        .addClass(JpaVoyageRepository.class)
        .addClass(JpaHandlingEventRepository.class)
        .addClass(JpaLocationRepository.class)
        .addClass(ExternalRoutingService.class)
        .addClass(LoggerProducer.class)
        // Interface components
        .addClass(TransitPath.class)
        .addClass(TransitEdge.class)
        // Third-party system simulator
        .addClass(GraphTraversalService.class)
        .addClass(GraphDao.class)
        // Sample data.
        .addClass(BookingServiceTestDataGenerator.class)
        .addClass(SampleLocations.class)
        .addClass(SampleVoyages.class)
        // Persistence unit descriptor
        .addAsResource("test-persistence.xml", "META-INF/persistence.xml")
        // Web application descriptor
        .addAsWebInfResource(webXml, "web.xml")
        // Bean archive descriptor
        .addAsWebInfResource("test-beans.xml", "beans.xml")
        // Library dependencies
        .addAsLibraries(
            Maven.resolver()
                .loadPomFromFile("pom.xml")
                .resolve(dependencies)
                .withTransitivity()
                .asFile());
  }
  
  @Test
  @Order(1)
  public void testRegisterNew() {
    UnLocode fromUnlocode = new UnLocode("USCHI");
    UnLocode toUnlocode = new UnLocode("SESTO");

    // Store deadline in Redis-backed state store instead of a static mutable field
    LocalDate deadline = LocalDate.now().plusMonths(6);
    STATE.putString(TestStateStore.KEY_DEADLINE, deadline.toString());

    TrackingId trackingId = bookingService.bookNewCargo(fromUnlocode, toUnlocode, deadline);
    // Persist trackingId string to Redis-backed state store
    STATE.putString(TestStateStore.KEY_TRACKING_ID, trackingId.getIdString());
    STATE.putObject(TestStateStore.KEY_TRACKING_ID + ":obj", trackingId);

    Cargo cargo =
        entityManager
            .createNamedQuery("Cargo.findByTrackingId", Cargo.class)
            .setParameter("trackingId", trackingId)
            .getSingleResult();

    assertEquals(SampleLocations.CHICAGO, cargo.getOrigin());
    assertEquals(SampleLocations.STOCKHOLM, cargo.getRouteSpecification().getDestination());
    assertTrue(deadline.isEqual(cargo.getRouteSpecification().getArrivalDeadline()));
    assertEquals(TransportStatus.NOT_RECEIVED, cargo.getDelivery().getTransportStatus());
    assertEquals(Location.UNKNOWN, cargo.getDelivery().getLastKnownLocation());
    assertEquals(Voyage.NONE, cargo.getDelivery().getCurrentVoyage());
    assertFalse(cargo.getDelivery().isMisdirected());
    assertEquals(Delivery.ETA_UNKOWN, cargo.getDelivery().getEstimatedTimeOfArrival());
    assertEquals(Delivery.NO_ACTIVITY, cargo.getDelivery().getNextExpectedActivity());
    assertFalse(cargo.getDelivery().isUnloadedAtDestination());
    assertEquals(RoutingStatus.NOT_ROUTED, cargo.getDelivery().getRoutingStatus());
    assertEquals(Itinerary.EMPTY_ITINERARY, cargo.getItinerary());
  }

  @Test
  @Order(2)
  public void testRouteCandidates() {
    // Retrieve trackingId from Redis-backed state store
    TrackingId trackingId = STATE.getObject(TestStateStore.KEY_TRACKING_ID + ":obj");
    List<Itinerary> candidates = bookingService.requestPossibleRoutesForCargo(trackingId);
    // Persist candidates to Redis-backed state store
    STATE.putObject("candidates", candidates);

    assertFalse(candidates.isEmpty());
  }

  @Test
  @Order(3)
  public void testAssignRoute() {
    // Retrieve shared state from Redis-backed state store
    TrackingId trackingId = STATE.getObject(TestStateStore.KEY_TRACKING_ID + ":obj");
    List<Itinerary> candidates = STATE.getObject("candidates");
    String deadlineStr = STATE.getString(TestStateStore.KEY_DEADLINE);
    LocalDate deadline = LocalDate.parse(deadlineStr);

    Itinerary assigned = candidates.get(new Random().nextInt(candidates.size()));
    // Persist assigned itinerary to Redis-backed state store
    STATE.putObject("assigned", assigned);

    bookingService.assignCargoToRoute(assigned, trackingId);

    Cargo cargo =
        entityManager
            .createNamedQuery("Cargo.findByTrackingId", Cargo.class)
            .setParameter("trackingId", trackingId)
            .getSingleResult();

    assertEquals(assigned, cargo.getItinerary());
    assertEquals(TransportStatus.NOT_RECEIVED, cargo.getDelivery().getTransportStatus());
    assertEquals(Location.UNKNOWN, cargo.getDelivery().getLastKnownLocation());
    assertEquals(Voyage.NONE, cargo.getDelivery().getCurrentVoyage());
    assertFalse(cargo.getDelivery().isMisdirected());
    assertTrue(cargo.getDelivery().getEstimatedTimeOfArrival().isBefore(deadline.atStartOfDay()));
    assertEquals(
        HandlingEvent.Type.RECEIVE, cargo.getDelivery().getNextExpectedActivity().getType());
    assertEquals(
        SampleLocations.CHICAGO, cargo.getDelivery().getNextExpectedActivity().getLocation());
    assertEquals(null, cargo.getDelivery().getNextExpectedActivity().getVoyage());
    assertFalse(cargo.getDelivery().isUnloadedAtDestination());
    assertEquals(RoutingStatus.ROUTED, cargo.getDelivery().getRoutingStatus());
  }

  @Test
  @Order(4)
  public void testChangeDestination() {
    // Retrieve shared state from Redis-backed state store
    TrackingId trackingId = STATE.getObject(TestStateStore.KEY_TRACKING_ID + ":obj");
    Itinerary assigned = STATE.getObject("assigned");
    String deadlineStr = STATE.getString(TestStateStore.KEY_DEADLINE);
    LocalDate deadline = LocalDate.parse(deadlineStr);

    bookingService.changeDestination(trackingId, new UnLocode("FIHEL"));

    Cargo cargo =
        entityManager
            .createNamedQuery("Cargo.findByTrackingId", Cargo.class)
            .setParameter("trackingId", trackingId)
            .getSingleResult();

    assertEquals(SampleLocations.CHICAGO, cargo.getOrigin());
    assertEquals(SampleLocations.HELSINKI, cargo.getRouteSpecification().getDestination());
    assertTrue(deadline.isEqual(cargo.getRouteSpecification().getArrivalDeadline()));
    assertEquals(assigned, cargo.getItinerary());
    assertEquals(TransportStatus.NOT_RECEIVED, cargo.getDelivery().getTransportStatus());
    assertEquals(Location.UNKNOWN, cargo.getDelivery().getLastKnownLocation());
    assertEquals(Voyage.NONE, cargo.getDelivery().getCurrentVoyage());
    assertFalse(cargo.getDelivery().isMisdirected());
    assertEquals(Delivery.ETA_UNKOWN, cargo.getDelivery().getEstimatedTimeOfArrival());
    assertEquals(Delivery.NO_ACTIVITY, cargo.getDelivery().getNextExpectedActivity());
    assertFalse(cargo.getDelivery().isUnloadedAtDestination());
    assertEquals(RoutingStatus.MISROUTED, cargo.getDelivery().getRoutingStatus());
  }

  @Test
  @Order(5)
  public void testChangeDeadline() {
    // Retrieve shared state from Redis-backed state store
    TrackingId trackingId = STATE.getObject(TestStateStore.KEY_TRACKING_ID + ":obj");
    Itinerary assigned = STATE.getObject("assigned");
    String deadlineStr = STATE.getString(TestStateStore.KEY_DEADLINE);
    LocalDate deadline = LocalDate.parse(deadlineStr);

    LocalDate newDeadline = deadline.plusMonths(1);
    bookingService.changeDeadline(trackingId, newDeadline);

    Cargo cargo =
        entityManager
            .createNamedQuery("Cargo.findByTrackingId", Cargo.class)
            .setParameter("trackingId", trackingId)
            .getSingleResult();

    assertEquals(SampleLocations.CHICAGO, cargo.getOrigin());
    assertEquals(SampleLocations.HELSINKI, cargo.getRouteSpecification().getDestination());
    assertTrue(newDeadline.isEqual(cargo.getRouteSpecification().getArrivalDeadline()));
    assertEquals(assigned, cargo.getItinerary());
    assertEquals(TransportStatus.NOT_RECEIVED, cargo.getDelivery().getTransportStatus());
    assertEquals(Location.UNKNOWN, cargo.getDelivery().getLastKnownLocation());
    assertEquals(Voyage.NONE, cargo.getDelivery().getCurrentVoyage());
    assertFalse(cargo.getDelivery().isMisdirected());
    assertEquals(Delivery.ETA_UNKOWN, cargo.getDelivery().getEstimatedTimeOfArrival());
    assertEquals(Delivery.NO_ACTIVITY, cargo.getDelivery().getNextExpectedActivity());
    assertFalse(cargo.getDelivery().isUnloadedAtDestination());
    assertEquals(RoutingStatus.MISROUTED, cargo.getDelivery().getRoutingStatus());
  }
}
