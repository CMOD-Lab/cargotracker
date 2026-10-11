package org.eclipse.cargotracker.domain.model.cargo;

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

@DisplayName("RouteSpecification Tests")
class RouteSpecificationTest {

    private Location stockholm;
    private Location hamburg;
    private Location newYork;
    private LocalDate arrivalDeadline;
    private RouteSpecification routeSpec;

    @BeforeEach
    void setUp() {
        stockholm = new Location(new UnLocode("SESTO"), "Stockholm");
        hamburg = new Location(new UnLocode("DEHAM"), "Hamburg");
        newYork = new Location(new UnLocode("USNYC"), "New York");
        arrivalDeadline = LocalDate.of(2024, 12, 31);
        routeSpec = new RouteSpecification(stockholm, newYork, arrivalDeadline);
    }

    @Test
    @DisplayName("Constructor creates RouteSpecification with all fields")
    void constructor_withValidArgs_createsRouteSpecification() {
        assertNotNull(routeSpec);
        assertEquals(stockholm, routeSpec.getOrigin());
        assertEquals(newYork, routeSpec.getDestination());
        assertEquals(arrivalDeadline, routeSpec.getArrivalDeadline());
    }

    @Test
    @DisplayName("Default constructor creates RouteSpecification")
    void defaultConstructor_createsRouteSpecification() {
        RouteSpecification rs = new RouteSpecification();
        assertNotNull(rs);
    }

    @Test
    @DisplayName("Constructor with null origin throws NullPointerException")
    void constructor_withNullOrigin_throwsException() {
        assertThrows(NullPointerException.class, () ->
                new RouteSpecification(null, newYork, arrivalDeadline));
    }

    @Test
    @DisplayName("Constructor with null destination throws NullPointerException")
    void constructor_withNullDestination_throwsException() {
        assertThrows(NullPointerException.class, () ->
                new RouteSpecification(stockholm, null, arrivalDeadline));
    }

    @Test
    @DisplayName("Constructor with null arrivalDeadline throws NullPointerException")
    void constructor_withNullArrivalDeadline_throwsException() {
        assertThrows(NullPointerException.class, () ->
                new RouteSpecification(stockholm, newYork, null));
    }

    @Test
    @DisplayName("Constructor with same origin and destination throws IllegalArgumentException")
    void constructor_withSameOriginAndDestination_throwsException() {
        assertThrows(IllegalArgumentException.class, () ->
                new RouteSpecification(stockholm, stockholm, arrivalDeadline));
    }

    @Test
    @DisplayName("getOrigin returns origin")
    void getOrigin_returnsOrigin() {
        assertEquals(stockholm, routeSpec.getOrigin());
    }

    @Test
    @DisplayName("getDestination returns destination")
    void getDestination_returnsDestination() {
        assertEquals(newYork, routeSpec.getDestination());
    }

    @Test
    @DisplayName("getArrivalDeadline returns arrival deadline")
    void getArrivalDeadline_returnsArrivalDeadline() {
        assertEquals(arrivalDeadline, routeSpec.getArrivalDeadline());
    }

    @Test
    @DisplayName("isSatisfiedBy returns true for valid itinerary")
    void isSatisfiedBy_validItinerary_returnsTrue() {
        Voyage voyage = new Voyage.Builder(new VoyageNumber("V001"), stockholm)
                .addMovement(newYork,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 10, 10, 0))
                .build();

        Leg leg = new Leg(voyage, stockholm, newYork,
                LocalDateTime.of(2024, 1, 1, 10, 0, 0),
                LocalDateTime.of(2024, 1, 10, 10, 0, 0));

        Itinerary itinerary = new Itinerary(Arrays.asList(leg));
        assertTrue(routeSpec.isSatisfiedBy(itinerary));
    }

    @Test
    @DisplayName("isSatisfiedBy returns false for null itinerary")
    void isSatisfiedBy_nullItinerary_returnsFalse() {
        assertFalse(routeSpec.isSatisfiedBy(null));
    }

    @Test
    @DisplayName("isSatisfiedBy returns false for wrong origin")
    void isSatisfiedBy_wrongOrigin_returnsFalse() {
        Voyage voyage = new Voyage.Builder(new VoyageNumber("V001"), hamburg)
                .addMovement(newYork,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 10, 10, 0))
                .build();

        Leg leg = new Leg(voyage, hamburg, newYork,
                LocalDateTime.of(2024, 1, 1, 10, 0, 0),
                LocalDateTime.of(2024, 1, 10, 10, 0, 0));

        Itinerary itinerary = new Itinerary(Arrays.asList(leg));
        assertFalse(routeSpec.isSatisfiedBy(itinerary));
    }

    @Test
    @DisplayName("isSatisfiedBy returns false for wrong destination")
    void isSatisfiedBy_wrongDestination_returnsFalse() {
        Voyage voyage = new Voyage.Builder(new VoyageNumber("V001"), stockholm)
                .addMovement(hamburg,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 3, 10, 0))
                .build();

        Leg leg = new Leg(voyage, stockholm, hamburg,
                LocalDateTime.of(2024, 1, 1, 10, 0, 0),
                LocalDateTime.of(2024, 1, 3, 10, 0, 0));

        Itinerary itinerary = new Itinerary(Arrays.asList(leg));
        assertFalse(routeSpec.isSatisfiedBy(itinerary));
    }

    @Test
    @DisplayName("isSatisfiedBy returns false when arrival is after deadline")
    void isSatisfiedBy_arrivalAfterDeadline_returnsFalse() {
        LocalDate pastDeadline = LocalDate.of(2024, 1, 1);
        RouteSpecification strictSpec = new RouteSpecification(stockholm, newYork, pastDeadline);

        Voyage voyage = new Voyage.Builder(new VoyageNumber("V001"), stockholm)
                .addMovement(newYork,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 6, 10, 10, 0))
                .build();

        Leg leg = new Leg(voyage, stockholm, newYork,
                LocalDateTime.of(2024, 1, 1, 10, 0, 0),
                LocalDateTime.of(2024, 6, 10, 10, 0, 0));

        Itinerary itinerary = new Itinerary(Arrays.asList(leg));
        assertFalse(strictSpec.isSatisfiedBy(itinerary));
    }

    @Test
    @DisplayName("equals returns true for same instance")
    void equals_sameInstance_returnsTrue() {
        assertEquals(routeSpec, routeSpec);
    }

    @Test
    @DisplayName("equals returns true for equal route specifications")
    void equals_equalRouteSpecs_returnsTrue() {
        RouteSpecification routeSpec2 = new RouteSpecification(stockholm, newYork, arrivalDeadline);
        assertEquals(routeSpec, routeSpec2);
    }

    @Test
    @DisplayName("equals returns false for different origin")
    void equals_differentOrigin_returnsFalse() {
        RouteSpecification routeSpec2 = new RouteSpecification(hamburg, newYork, arrivalDeadline);
        assertNotEquals(routeSpec, routeSpec2);
    }

    @Test
    @DisplayName("hashCode is consistent for equal route specifications")
    void hashCode_equalRouteSpecs_sameHashCode() {
        RouteSpecification routeSpec2 = new RouteSpecification(stockholm, newYork, arrivalDeadline);
        assertEquals(routeSpec.hashCode(), routeSpec2.hashCode());
    }
}
