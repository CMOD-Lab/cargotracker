package org.eclipse.cargotracker.domain.model.cargo;

import org.eclipse.cargotracker.domain.model.handling.HandlingEvent;
import org.eclipse.cargotracker.domain.model.handling.HandlingHistory;
import org.eclipse.cargotracker.domain.model.location.Location;
import org.eclipse.cargotracker.domain.model.location.UnLocode;
import org.eclipse.cargotracker.domain.model.voyage.Voyage;
import org.eclipse.cargotracker.domain.model.voyage.VoyageNumber;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Arrays;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Cargo Tests")
class CargoTest {

    private Location stockholm;
    private Location hamburg;
    private Location newYork;
    private TrackingId trackingId;
    private RouteSpecification routeSpec;
    private Cargo cargo;
    private Voyage voyage1;
    private Voyage voyage2;
    private Leg leg1;
    private Leg leg2;
    private Itinerary itinerary;

    @BeforeEach
    void setUp() {
        stockholm = new Location(new UnLocode("SESTO"), "Stockholm");
        hamburg = new Location(new UnLocode("DEHAM"), "Hamburg");
        newYork = new Location(new UnLocode("USNYC"), "New York");

        trackingId = new TrackingId("TEST001");
        routeSpec = new RouteSpecification(stockholm, newYork, LocalDate.of(2024, 12, 31));
        cargo = new Cargo(trackingId, routeSpec);

        voyage1 = new Voyage.Builder(new VoyageNumber("V001"), stockholm)
                .addMovement(hamburg,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 3, 10, 0))
                .build();

        voyage2 = new Voyage.Builder(new VoyageNumber("V002"), hamburg)
                .addMovement(newYork,
                        LocalDateTime.of(2024, 1, 4, 10, 0),
                        LocalDateTime.of(2024, 1, 10, 10, 0))
                .build();

        leg1 = new Leg(voyage1, stockholm, hamburg,
                LocalDateTime.of(2024, 1, 1, 10, 0, 0),
                LocalDateTime.of(2024, 1, 3, 10, 0, 0));
        leg2 = new Leg(voyage2, hamburg, newYork,
                LocalDateTime.of(2024, 1, 4, 10, 0, 0),
                LocalDateTime.of(2024, 1, 10, 10, 0, 0));

        itinerary = new Itinerary(Arrays.asList(leg1, leg2));
    }

    @Test
    @DisplayName("Constructor creates Cargo with trackingId and routeSpec")
    void constructor_withValidArgs_createsCargo() {
        assertNotNull(cargo);
        assertEquals(trackingId, cargo.getTrackingId());
        assertEquals(routeSpec, cargo.getRouteSpecification());
        assertEquals(stockholm, cargo.getOrigin());
    }

    @Test
    @DisplayName("Default constructor creates Cargo")
    void defaultConstructor_createsCargo() {
        Cargo c = new Cargo();
        assertNotNull(c);
    }

    @Test
    @DisplayName("Constructor with null trackingId throws NullPointerException")
    void constructor_withNullTrackingId_throwsException() {
        assertThrows(NullPointerException.class, () ->
                new Cargo(null, routeSpec));
    }

    @Test
    @DisplayName("Constructor with null routeSpec throws NullPointerException")
    void constructor_withNullRouteSpec_throwsException() {
        assertThrows(NullPointerException.class, () ->
                new Cargo(trackingId, null));
    }

    @Test
    @DisplayName("getTrackingId returns the tracking id")
    void getTrackingId_returnsTrackingId() {
        assertEquals(trackingId, cargo.getTrackingId());
    }

    @Test
    @DisplayName("getOrigin returns the origin from route specification")
    void getOrigin_returnsOrigin() {
        assertEquals(stockholm, cargo.getOrigin());
    }

    @Test
    @DisplayName("getRouteSpecification returns the route specification")
    void getRouteSpecification_returnsRouteSpec() {
        assertEquals(routeSpec, cargo.getRouteSpecification());
    }

    @Test
    @DisplayName("getDelivery returns non-null delivery")
    void getDelivery_returnsNonNullDelivery() {
        assertNotNull(cargo.getDelivery());
    }

    @Test
    @DisplayName("getItinerary returns EMPTY_ITINERARY initially")
    void getItinerary_initially_returnsEmptyItinerary() {
        assertEquals(Itinerary.EMPTY_ITINERARY, cargo.getItinerary());
    }

    @Test
    @DisplayName("assignToRoute sets the itinerary")
    void assignToRoute_setsItinerary() {
        cargo.assignToRoute(itinerary);
        assertEquals(itinerary, cargo.getItinerary());
    }

    @Test
    @DisplayName("assignToRoute with null throws NullPointerException")
    void assignToRoute_withNull_throwsException() {
        assertThrows(NullPointerException.class, () -> cargo.assignToRoute(null));
    }

    @Test
    @DisplayName("specifyNewRoute updates the route specification")
    void specifyNewRoute_updatesRouteSpec() {
        RouteSpecification newRouteSpec = new RouteSpecification(stockholm, hamburg,
                LocalDate.of(2024, 6, 30));
        cargo.specifyNewRoute(newRouteSpec);
        assertEquals(newRouteSpec, cargo.getRouteSpecification());
    }

    @Test
    @DisplayName("specifyNewRoute with null throws NullPointerException")
    void specifyNewRoute_withNull_throwsException() {
        assertThrows(NullPointerException.class, () -> cargo.specifyNewRoute(null));
    }

    @Test
    @DisplayName("deriveDeliveryProgress updates delivery")
    void deriveDeliveryProgress_updatesDelivery() {
        cargo.assignToRoute(itinerary);
        HandlingHistory history = HandlingHistory.EMPTY;
        cargo.deriveDeliveryProgress(history);
        assertNotNull(cargo.getDelivery());
    }

    @Test
    @DisplayName("equals returns true for same instance")
    void equals_sameInstance_returnsTrue() {
        assertEquals(cargo, cargo);
    }

    @Test
    @DisplayName("equals returns true for same tracking id")
    void equals_sameTrackingId_returnsTrue() {
        Cargo cargo2 = new Cargo(new TrackingId("TEST001"), routeSpec);
        assertEquals(cargo, cargo2);
    }

    @Test
    @DisplayName("equals returns false for different tracking id")
    void equals_differentTrackingId_returnsFalse() {
        Cargo cargo2 = new Cargo(new TrackingId("TEST002"), routeSpec);
        assertNotEquals(cargo, cargo2);
    }

    @Test
    @DisplayName("equals returns false for null")
    void equals_null_returnsFalse() {
        assertNotEquals(null, cargo);
    }

    @Test
    @DisplayName("hashCode is consistent for equal cargos")
    void hashCode_equalCargos_sameHashCode() {
        Cargo cargo2 = new Cargo(new TrackingId("TEST001"), routeSpec);
        assertEquals(cargo.hashCode(), cargo2.hashCode());
    }

    @Test
    @DisplayName("toString returns tracking id")
    void toString_returnsTrackingId() {
        assertEquals("TEST001", cargo.toString());
    }

    @Test
    @DisplayName("setOrigin updates origin")
    void setOrigin_updatesOrigin() {
        cargo.setOrigin(hamburg);
        assertEquals(hamburg, cargo.getOrigin());
    }

    @Test
    @DisplayName("Delivery is NOT_ROUTED initially")
    void delivery_initially_isNotRouted() {
        assertEquals(RoutingStatus.NOT_ROUTED, cargo.getDelivery().getRoutingStatus());
    }

    @Test
    @DisplayName("Delivery is ROUTED after assigning valid itinerary")
    void delivery_afterAssigningItinerary_isRouted() {
        cargo.assignToRoute(itinerary);
        assertEquals(RoutingStatus.ROUTED, cargo.getDelivery().getRoutingStatus());
    }
}
