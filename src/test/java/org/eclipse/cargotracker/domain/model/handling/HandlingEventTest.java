package org.eclipse.cargotracker.domain.model.handling;

import org.eclipse.cargotracker.domain.model.cargo.Cargo;
import org.eclipse.cargotracker.domain.model.cargo.RouteSpecification;
import org.eclipse.cargotracker.domain.model.cargo.TrackingId;
import org.eclipse.cargotracker.domain.model.location.Location;
import org.eclipse.cargotracker.domain.model.location.UnLocode;
import org.eclipse.cargotracker.domain.model.voyage.Voyage;
import org.eclipse.cargotracker.domain.model.voyage.VoyageNumber;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.time.LocalDate;
import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("HandlingEvent Tests")
class HandlingEventTest {

    private Location stockholm;
    private Location hamburg;
    private Location newYork;
    private Voyage voyage;
    private Cargo cargo;
    private LocalDateTime completionTime;
    private LocalDateTime registrationTime;

    @BeforeEach
    void setUp() {
        stockholm = new Location(new UnLocode("SESTO"), "Stockholm");
        hamburg = new Location(new UnLocode("DEHAM"), "Hamburg");
        newYork = new Location(new UnLocode("USNYC"), "New York");

        voyage = new Voyage.Builder(new VoyageNumber("V001"), stockholm)
                .addMovement(hamburg,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 3, 10, 0))
                .build();

        TrackingId trackingId = new TrackingId("TEST001");
        RouteSpecification routeSpec = new RouteSpecification(stockholm, newYork,
                LocalDate.of(2024, 12, 31));
        cargo = new Cargo(trackingId, routeSpec);

        completionTime = LocalDateTime.of(2024, 1, 1, 10, 0, 0);
        registrationTime = LocalDateTime.of(2024, 1, 1, 10, 0, 0);
    }

    @Test
    @DisplayName("Constructor with voyage creates HandlingEvent for LOAD type")
    void constructor_withVoyage_createsLoadEvent() {
        HandlingEvent event = new HandlingEvent(cargo, completionTime, registrationTime,
                HandlingEvent.Type.LOAD, stockholm, voyage);
        assertNotNull(event);
        assertEquals(HandlingEvent.Type.LOAD, event.getType());
        assertEquals(stockholm, event.getLocation());
        assertEquals(voyage, event.getVoyage());
        assertEquals(cargo, event.getCargo());
    }

    @Test
    @DisplayName("Constructor without voyage creates HandlingEvent for RECEIVE type")
    void constructor_withoutVoyage_createsReceiveEvent() {
        HandlingEvent event = new HandlingEvent(cargo, completionTime, registrationTime,
                HandlingEvent.Type.RECEIVE, stockholm);
        assertNotNull(event);
        assertEquals(HandlingEvent.Type.RECEIVE, event.getType());
        assertEquals(stockholm, event.getLocation());
        assertEquals(cargo, event.getCargo());
    }

    @Test
    @DisplayName("Default constructor creates HandlingEvent")
    void defaultConstructor_createsHandlingEvent() {
        HandlingEvent event = new HandlingEvent();
        assertNotNull(event);
    }

    @Test
    @DisplayName("Constructor with voyage for RECEIVE type throws IllegalArgumentException")
    void constructor_withVoyageForReceiveType_throwsException() {
        assertThrows(IllegalArgumentException.class, () ->
                new HandlingEvent(cargo, completionTime, registrationTime,
                        HandlingEvent.Type.RECEIVE, stockholm, voyage));
    }

    @Test
    @DisplayName("Constructor without voyage for LOAD type throws IllegalArgumentException")
    void constructor_withoutVoyageForLoadType_throwsException() {
        assertThrows(IllegalArgumentException.class, () ->
                new HandlingEvent(cargo, completionTime, registrationTime,
                        HandlingEvent.Type.LOAD, stockholm));
    }

    @Test
    @DisplayName("Constructor with null cargo throws NullPointerException")
    void constructor_withNullCargo_throwsException() {
        assertThrows(NullPointerException.class, () ->
                new HandlingEvent(null, completionTime, registrationTime,
                        HandlingEvent.Type.RECEIVE, stockholm));
    }

    @Test
    @DisplayName("Constructor with null completionTime throws NullPointerException")
    void constructor_withNullCompletionTime_throwsException() {
        assertThrows(NullPointerException.class, () ->
                new HandlingEvent(cargo, null, registrationTime,
                        HandlingEvent.Type.RECEIVE, stockholm));
    }

    @Test
    @DisplayName("Constructor with null location throws NullPointerException")
    void constructor_withNullLocation_throwsException() {
        assertThrows(NullPointerException.class, () ->
                new HandlingEvent(cargo, completionTime, registrationTime,
                        HandlingEvent.Type.RECEIVE, null));
    }

    @Test
    @DisplayName("getType returns the event type")
    void getType_returnsEventType() {
        HandlingEvent event = new HandlingEvent(cargo, completionTime, registrationTime,
                HandlingEvent.Type.RECEIVE, stockholm);
        assertEquals(HandlingEvent.Type.RECEIVE, event.getType());
    }

    @Test
    @DisplayName("getVoyage returns NONE for event without voyage")
    void getVoyage_withoutVoyage_returnsNone() {
        HandlingEvent event = new HandlingEvent(cargo, completionTime, registrationTime,
                HandlingEvent.Type.RECEIVE, stockholm);
        assertEquals(Voyage.NONE, event.getVoyage());
    }

    @Test
    @DisplayName("getVoyage returns voyage for event with voyage")
    void getVoyage_withVoyage_returnsVoyage() {
        HandlingEvent event = new HandlingEvent(cargo, completionTime, registrationTime,
                HandlingEvent.Type.LOAD, stockholm, voyage);
        assertEquals(voyage, event.getVoyage());
    }

    @Test
    @DisplayName("getCompletionTime returns completion time")
    void getCompletionTime_returnsCompletionTime() {
        HandlingEvent event = new HandlingEvent(cargo, completionTime, registrationTime,
                HandlingEvent.Type.RECEIVE, stockholm);
        assertEquals(completionTime, event.getCompletionTime());
    }

    @Test
    @DisplayName("getRegistrationTime returns registration time")
    void getRegistrationTime_returnsRegistrationTime() {
        HandlingEvent event = new HandlingEvent(cargo, completionTime, registrationTime,
                HandlingEvent.Type.RECEIVE, stockholm);
        assertEquals(registrationTime, event.getRegistrationTime());
    }

    @Test
    @DisplayName("getLocation returns location")
    void getLocation_returnsLocation() {
        HandlingEvent event = new HandlingEvent(cargo, completionTime, registrationTime,
                HandlingEvent.Type.RECEIVE, stockholm);
        assertEquals(stockholm, event.getLocation());
    }

    @Test
    @DisplayName("getCargo returns cargo")
    void getCargo_returnsCargo() {
        HandlingEvent event = new HandlingEvent(cargo, completionTime, registrationTime,
                HandlingEvent.Type.RECEIVE, stockholm);
        assertEquals(cargo, event.getCargo());
    }

    @Test
    @DisplayName("getSummary returns non-null string")
    void getSummary_returnsNonNullString() {
        HandlingEvent event = new HandlingEvent(cargo, completionTime, registrationTime,
                HandlingEvent.Type.RECEIVE, stockholm);
        assertNotNull(event.getSummary());
        assertTrue(event.getSummary().contains("Stockholm"));
    }

    @Test
    @DisplayName("getSummary includes voyage number when voyage is present")
    void getSummary_withVoyage_includesVoyageNumber() {
        HandlingEvent event = new HandlingEvent(cargo, completionTime, registrationTime,
                HandlingEvent.Type.LOAD, stockholm, voyage);
        assertTrue(event.getSummary().contains("V001"));
    }

    @Test
    @DisplayName("equals returns true for same instance")
    void equals_sameInstance_returnsTrue() {
        HandlingEvent event = new HandlingEvent(cargo, completionTime, registrationTime,
                HandlingEvent.Type.RECEIVE, stockholm);
        assertEquals(event, event);
    }

    @Test
    @DisplayName("equals returns false for null")
    void equals_null_returnsFalse() {
        HandlingEvent event = new HandlingEvent(cargo, completionTime, registrationTime,
                HandlingEvent.Type.RECEIVE, stockholm);
        assertNotEquals(null, event);
    }

    @Test
    @DisplayName("toString returns non-null string")
    void toString_returnsNonNullString() {
        HandlingEvent event = new HandlingEvent(cargo, completionTime, registrationTime,
                HandlingEvent.Type.RECEIVE, stockholm);
        assertNotNull(event.toString());
    }

    @Test
    @DisplayName("Type.LOAD requires voyage")
    void typeLoad_requiresVoyage() {
        assertTrue(HandlingEvent.Type.LOAD.requiresVoyage());
        assertFalse(HandlingEvent.Type.LOAD.prohibitsVoyage());
    }

    @Test
    @DisplayName("Type.RECEIVE prohibits voyage")
    void typeReceive_prohibitsVoyage() {
        assertFalse(HandlingEvent.Type.RECEIVE.requiresVoyage());
        assertTrue(HandlingEvent.Type.RECEIVE.prohibitsVoyage());
    }

    @Test
    @DisplayName("Type.CLAIM prohibits voyage")
    void typeClaim_prohibitsVoyage() {
        assertFalse(HandlingEvent.Type.CLAIM.requiresVoyage());
        assertTrue(HandlingEvent.Type.CLAIM.prohibitsVoyage());
    }

    @Test
    @DisplayName("Type.CUSTOMS prohibits voyage")
    void typeCustoms_prohibitsVoyage() {
        assertFalse(HandlingEvent.Type.CUSTOMS.requiresVoyage());
        assertTrue(HandlingEvent.Type.CUSTOMS.prohibitsVoyage());
    }

    @Test
    @DisplayName("Type.UNLOAD requires voyage")
    void typeUnload_requiresVoyage() {
        assertTrue(HandlingEvent.Type.UNLOAD.requiresVoyage());
        assertFalse(HandlingEvent.Type.UNLOAD.prohibitsVoyage());
    }

    @Test
    @DisplayName("Type.sameValueAs returns true for same type")
    void typeSameValueAs_sameType_returnsTrue() {
        assertTrue(HandlingEvent.Type.LOAD.sameValueAs(HandlingEvent.Type.LOAD));
    }

    @Test
    @DisplayName("Type.sameValueAs returns false for different type")
    void typeSameValueAs_differentType_returnsFalse() {
        assertFalse(HandlingEvent.Type.LOAD.sameValueAs(HandlingEvent.Type.UNLOAD));
    }
}
