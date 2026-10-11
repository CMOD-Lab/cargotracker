package org.eclipse.cargotracker.domain.model.cargo;

import org.eclipse.cargotracker.domain.model.handling.HandlingEvent;
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
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Itinerary Tests")
class ItineraryTest {

    private Location stockholm;
    private Location hamburg;
    private Location newYork;
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
    @DisplayName("Constructor creates Itinerary with legs")
    void constructor_withValidLegs_createsItinerary() {
        assertNotNull(itinerary);
        assertEquals(2, itinerary.getLegs().size());
    }

    @Test
    @DisplayName("Default constructor creates empty Itinerary")
    void defaultConstructor_createsEmptyItinerary() {
        Itinerary i = new Itinerary();
        assertNotNull(i);
    }

    @Test
    @DisplayName("EMPTY_ITINERARY is not null")
    void emptyItinerary_isNotNull() {
        assertNotNull(Itinerary.EMPTY_ITINERARY);
    }

    @Test
    @DisplayName("Constructor with null legs throws exception")
    void constructor_withNullLegs_throwsException() {
        assertThrows(Exception.class, () -> new Itinerary(null));
    }

    @Test
    @DisplayName("Constructor with empty legs throws exception")
    void constructor_withEmptyLegs_throwsException() {
        assertThrows(Exception.class, () -> new Itinerary(Collections.emptyList()));
    }

    @Test
    @DisplayName("getLegs returns unmodifiable list")
    void getLegs_returnsUnmodifiableList() {
        List<Leg> legs = itinerary.getLegs();
        assertNotNull(legs);
        assertEquals(2, legs.size());
        assertThrows(UnsupportedOperationException.class, () -> legs.add(leg1));
    }

    @Test
    @DisplayName("isExpected returns true for RECEIVE event at first leg load location")
    void isExpected_receiveEventAtFirstLeg_returnsTrue() {
        TrackingId trackingId = new TrackingId("TEST001");
        RouteSpecification routeSpec = new RouteSpecification(stockholm, newYork,
                java.time.LocalDate.of(2024, 12, 31));
        Cargo cargo = new Cargo(trackingId, routeSpec);

        HandlingEvent receiveEvent = new HandlingEvent(cargo,
                LocalDateTime.of(2024, 1, 1, 9, 0, 0),
                LocalDateTime.of(2024, 1, 1, 9, 0, 0),
                HandlingEvent.Type.RECEIVE,
                stockholm);

        assertTrue(itinerary.isExpected(receiveEvent));
    }

    @Test
    @DisplayName("isExpected returns true for LOAD event at correct location and voyage")
    void isExpected_loadEventAtCorrectLocation_returnsTrue() {
        TrackingId trackingId = new TrackingId("TEST001");
        RouteSpecification routeSpec = new RouteSpecification(stockholm, newYork,
                java.time.LocalDate.of(2024, 12, 31));
        Cargo cargo = new Cargo(trackingId, routeSpec);

        HandlingEvent loadEvent = new HandlingEvent(cargo,
                LocalDateTime.of(2024, 1, 1, 10, 0, 0),
                LocalDateTime.of(2024, 1, 1, 10, 0, 0),
                HandlingEvent.Type.LOAD,
                stockholm,
                voyage1);

        assertTrue(itinerary.isExpected(loadEvent));
    }

    @Test
    @DisplayName("isExpected returns true for UNLOAD event at correct location and voyage")
    void isExpected_unloadEventAtCorrectLocation_returnsTrue() {
        TrackingId trackingId = new TrackingId("TEST001");
        RouteSpecification routeSpec = new RouteSpecification(stockholm, newYork,
                java.time.LocalDate.of(2024, 12, 31));
        Cargo cargo = new Cargo(trackingId, routeSpec);

        HandlingEvent unloadEvent = new HandlingEvent(cargo,
                LocalDateTime.of(2024, 1, 3, 10, 0, 0),
                LocalDateTime.of(2024, 1, 3, 10, 0, 0),
                HandlingEvent.Type.UNLOAD,
                hamburg,
                voyage1);

        assertTrue(itinerary.isExpected(unloadEvent));
    }

    @Test
    @DisplayName("isExpected returns true for CLAIM event at last leg unload location")
    void isExpected_claimEventAtLastLeg_returnsTrue() {
        TrackingId trackingId = new TrackingId("TEST001");
        RouteSpecification routeSpec = new RouteSpecification(stockholm, newYork,
                java.time.LocalDate.of(2024, 12, 31));
        Cargo cargo = new Cargo(trackingId, routeSpec);

        HandlingEvent claimEvent = new HandlingEvent(cargo,
                LocalDateTime.of(2024, 1, 11, 10, 0, 0),
                LocalDateTime.of(2024, 1, 11, 10, 0, 0),
                HandlingEvent.Type.CLAIM,
                newYork);

        assertTrue(itinerary.isExpected(claimEvent));
    }

    @Test
    @DisplayName("isExpected returns true for CUSTOMS event")
    void isExpected_customsEvent_returnsTrue() {
        TrackingId trackingId = new TrackingId("TEST001");
        RouteSpecification routeSpec = new RouteSpecification(stockholm, newYork,
                java.time.LocalDate.of(2024, 12, 31));
        Cargo cargo = new Cargo(trackingId, routeSpec);

        HandlingEvent customsEvent = new HandlingEvent(cargo,
                LocalDateTime.of(2024, 1, 5, 10, 0, 0),
                LocalDateTime.of(2024, 1, 5, 10, 0, 0),
                HandlingEvent.Type.CUSTOMS,
                hamburg);

        assertTrue(itinerary.isExpected(customsEvent));
    }

    @Test
    @DisplayName("equals returns true for same instance")
    void equals_sameInstance_returnsTrue() {
        assertEquals(itinerary, itinerary);
    }

    @Test
    @DisplayName("equals returns true for equal itineraries")
    void equals_equalItineraries_returnsTrue() {
        Itinerary itinerary2 = new Itinerary(Arrays.asList(leg1, leg2));
        assertEquals(itinerary, itinerary2);
    }

    @Test
    @DisplayName("equals returns false for different itineraries")
    void equals_differentItineraries_returnsFalse() {
        Itinerary itinerary2 = new Itinerary(Arrays.asList(leg1));
        assertNotEquals(itinerary, itinerary2);
    }

    @Test
    @DisplayName("hashCode is consistent for equal itineraries")
    void hashCode_equalItineraries_sameHashCode() {
        Itinerary itinerary2 = new Itinerary(Arrays.asList(leg1, leg2));
        assertEquals(itinerary.hashCode(), itinerary2.hashCode());
    }

    @Test
    @DisplayName("toString contains legs information")
    void toString_containsLegsInfo() {
        String result = itinerary.toString();
        assertNotNull(result);
        assertTrue(result.contains("Itinerary"));
    }
}
