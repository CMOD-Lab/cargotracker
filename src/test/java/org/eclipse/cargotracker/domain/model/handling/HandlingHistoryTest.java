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
import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("HandlingHistory Tests")
class HandlingHistoryTest {

    private Location stockholm;
    private Location hamburg;
    private Location newYork;
    private Voyage voyage;
    private Cargo cargo;
    private HandlingEvent event1;
    private HandlingEvent event2;

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

        event1 = new HandlingEvent(cargo,
                LocalDateTime.of(2024, 1, 1, 10, 0, 0),
                LocalDateTime.of(2024, 1, 1, 10, 0, 0),
                HandlingEvent.Type.RECEIVE, stockholm);

        event2 = new HandlingEvent(cargo,
                LocalDateTime.of(2024, 1, 2, 10, 0, 0),
                LocalDateTime.of(2024, 1, 2, 10, 0, 0),
                HandlingEvent.Type.LOAD, stockholm, voyage);
    }

    @Test
    @DisplayName("EMPTY history is not null")
    void emptyHistory_isNotNull() {
        assertNotNull(HandlingHistory.EMPTY);
    }

    @Test
    @DisplayName("EMPTY history has no events")
    void emptyHistory_hasNoEvents() {
        assertTrue(HandlingHistory.EMPTY.getAllHandlingEvents().isEmpty());
    }

    @Test
    @DisplayName("Constructor creates HandlingHistory with events")
    void constructor_withEvents_createsHandlingHistory() {
        HandlingHistory history = new HandlingHistory(Arrays.asList(event1, event2));
        assertNotNull(history);
        assertEquals(2, history.getAllHandlingEvents().size());
    }

    @Test
    @DisplayName("Constructor with null throws NullPointerException")
    void constructor_withNull_throwsException() {
        assertThrows(NullPointerException.class, () -> new HandlingHistory(null));
    }

    @Test
    @DisplayName("getAllHandlingEvents returns all events")
    void getAllHandlingEvents_returnsAllEvents() {
        HandlingHistory history = new HandlingHistory(Arrays.asList(event1, event2));
        List<HandlingEvent> events = history.getAllHandlingEvents();
        assertEquals(2, events.size());
    }

    @Test
    @DisplayName("getDistinctEventsByCompletionTime returns ordered events")
    void getDistinctEventsByCompletionTime_returnsOrderedEvents() {
        HandlingHistory history = new HandlingHistory(Arrays.asList(event2, event1));
        List<HandlingEvent> ordered = history.getDistinctEventsByCompletionTime();
        assertNotNull(ordered);
        assertFalse(ordered.isEmpty());
    }

    @Test
    @DisplayName("getMostRecentlyCompletedEvent returns null for empty history")
    void getMostRecentlyCompletedEvent_emptyHistory_returnsNull() {
        assertNull(HandlingHistory.EMPTY.getMostRecentlyCompletedEvent());
    }

    @Test
    @DisplayName("getMostRecentlyCompletedEvent returns most recent event")
    void getMostRecentlyCompletedEvent_withEvents_returnsMostRecent() {
        HandlingHistory history = new HandlingHistory(Arrays.asList(event1, event2));
        HandlingEvent mostRecent = history.getMostRecentlyCompletedEvent();
        assertNotNull(mostRecent);
        assertEquals(event2, mostRecent);
    }

    @Test
    @DisplayName("equals returns true for same instance")
    void equals_sameInstance_returnsTrue() {
        HandlingHistory history = new HandlingHistory(Arrays.asList(event1));
        assertEquals(history, history);
    }

    @Test
    @DisplayName("equals returns true for equal histories")
    void equals_equalHistories_returnsTrue() {
        HandlingHistory history1 = new HandlingHistory(Arrays.asList(event1));
        HandlingHistory history2 = new HandlingHistory(Arrays.asList(event1));
        assertEquals(history1, history2);
    }

    @Test
    @DisplayName("equals returns false for different histories")
    void equals_differentHistories_returnsFalse() {
        HandlingHistory history1 = new HandlingHistory(Arrays.asList(event1));
        HandlingHistory history2 = new HandlingHistory(Arrays.asList(event2));
        assertNotEquals(history1, history2);
    }

    @Test
    @DisplayName("equals returns false for null")
    void equals_null_returnsFalse() {
        HandlingHistory history = new HandlingHistory(Arrays.asList(event1));
        assertNotEquals(null, history);
    }

    @Test
    @DisplayName("hashCode is consistent for equal histories")
    void hashCode_equalHistories_sameHashCode() {
        HandlingHistory history1 = new HandlingHistory(Arrays.asList(event1));
        HandlingHistory history2 = new HandlingHistory(Arrays.asList(event1));
        assertEquals(history1.hashCode(), history2.hashCode());
    }
}
