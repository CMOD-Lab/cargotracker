package org.eclipse.cargotracker.interfaces.booking.facade.dto;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.time.LocalDate;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("CargoRoute DTO Tests")
class CargoRouteTest {

    private Location origin;
    private Location destination;
    private Location lastKnownLocation;
    private List<Leg> legs;
    private CargoRoute cargoRoute;

    @BeforeEach
    void setUp() {
        origin = new Location("SESTO", "Stockholm");
        destination = new Location("USNYC", "New York");
        lastKnownLocation = new Location("DEHAM", "Hamburg");

        Location from = new Location("SESTO", "Stockholm");
        Location to = new Location("DEHAM", "Hamburg");
        Leg leg = new Leg("V001", from, to,
                java.time.LocalDateTime.of(2024, 1, 1, 10, 0),
                java.time.LocalDateTime.of(2024, 1, 3, 10, 0));
        legs = Arrays.asList(leg);

        cargoRoute = new CargoRoute(
                "TEST001",
                origin,
                destination,
                LocalDate.of(2024, 12, 31),
                false,
                false,
                lastKnownLocation,
                "IN_PORT",
                legs);
    }

    @Test
    @DisplayName("Constructor creates CargoRoute with all fields")
    void constructor_withValidArgs_createsCargoRoute() {
        assertNotNull(cargoRoute);
        assertEquals("TEST001", cargoRoute.getTrackingId());
    }

    @Test
    @DisplayName("getTrackingId returns tracking id")
    void getTrackingId_returnsTrackingId() {
        assertEquals("TEST001", cargoRoute.getTrackingId());
    }

    @Test
    @DisplayName("getOrigin returns origin as string")
    void getOrigin_returnsOriginString() {
        assertNotNull(cargoRoute.getOrigin());
        assertTrue(cargoRoute.getOrigin().contains("Stockholm"));
    }

    @Test
    @DisplayName("getOriginName returns origin name")
    void getOriginName_returnsOriginName() {
        assertEquals("Stockholm", cargoRoute.getOriginName());
    }

    @Test
    @DisplayName("getOriginCode returns origin code")
    void getOriginCode_returnsOriginCode() {
        assertEquals("SESTO", cargoRoute.getOriginCode());
    }

    @Test
    @DisplayName("getFinalDestination returns destination as string")
    void getFinalDestination_returnsDestinationString() {
        assertNotNull(cargoRoute.getFinalDestination());
        assertTrue(cargoRoute.getFinalDestination().contains("New York"));
    }

    @Test
    @DisplayName("getFinalDestinationName returns destination name")
    void getFinalDestinationName_returnsDestinationName() {
        assertEquals("New York", cargoRoute.getFinalDestinationName());
    }

    @Test
    @DisplayName("getFinalDestinationCode returns destination code")
    void getFinalDestinationCode_returnsDestinationCode() {
        assertEquals("USNYC", cargoRoute.getFinalDestinationCode());
    }

    @Test
    @DisplayName("getLegs returns legs")
    void getLegs_returnsLegs() {
        assertNotNull(cargoRoute.getLegs());
        assertEquals(1, cargoRoute.getLegs().size());
    }

    @Test
    @DisplayName("isMisrouted returns false when not misrouted")
    void isMisrouted_notMisrouted_returnsFalse() {
        assertFalse(cargoRoute.isMisrouted());
    }

    @Test
    @DisplayName("isRouted returns true when legs are not empty")
    void isRouted_withLegs_returnsTrue() {
        assertTrue(cargoRoute.isRouted());
    }

    @Test
    @DisplayName("isRouted returns false when legs are empty")
    void isRouted_withEmptyLegs_returnsFalse() {
        CargoRoute emptyRoute = new CargoRoute(
                "TEST002", origin, destination,
                LocalDate.of(2024, 12, 31),
                false, false, lastKnownLocation, "NOT_RECEIVED",
                Collections.emptyList());
        assertFalse(emptyRoute.isRouted());
    }

    @Test
    @DisplayName("getArrivalDeadline returns formatted date")
    void getArrivalDeadline_returnsFormattedDate() {
        assertNotNull(cargoRoute.getArrivalDeadline());
        assertEquals("12/31/2024", cargoRoute.getArrivalDeadline());
    }

    @Test
    @DisplayName("isClaimed returns false when not claimed")
    void isClaimed_notClaimed_returnsFalse() {
        assertFalse(cargoRoute.isClaimed());
    }

    @Test
    @DisplayName("getLastKnownLocation returns location string")
    void getLastKnownLocation_returnsLocationString() {
        assertNotNull(cargoRoute.getLastKnownLocation());
        assertTrue(cargoRoute.getLastKnownLocation().contains("Hamburg"));
    }

    @Test
    @DisplayName("getLastKnownLocationName returns location name")
    void getLastKnownLocationName_returnsLocationName() {
        assertEquals("Hamburg", cargoRoute.getLastKnownLocationName());
    }

    @Test
    @DisplayName("getLastKnownLocationCode returns location code")
    void getLastKnownLocationCode_returnsLocationCode() {
        assertEquals("DEHAM", cargoRoute.getLastKnownLocationCode());
    }

    @Test
    @DisplayName("getTransportStatus returns transport status")
    void getTransportStatus_returnsTransportStatus() {
        assertEquals("IN_PORT", cargoRoute.getTransportStatus());
    }
}
