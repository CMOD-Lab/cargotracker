package org.eclipse.cargotracker.interfaces.booking.facade.dto;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("CargoStatus DTO Tests")
class CargoStatusTest {

    private CargoStatus cargoStatus;
    private List<TrackingEvents> events;

    @BeforeEach
    void setUp() {
        TrackingEvents event1 = new TrackingEvents(true, "Received in Stockholm", "1/1/2024 10:0 AM");
        TrackingEvents event2 = new TrackingEvents(false, "Loaded in Hamburg", "1/3/2024 10:0 AM");
        events = Arrays.asList(event1, event2);

        cargoStatus = new CargoStatus(
                "TEST001",
                "New York",
                "In port",
                false,
                "12/31/2024 10:0 AM",
                "Load in Hamburg",
                events);
    }

    @Test
    @DisplayName("Constructor creates CargoStatus with all fields")
    void constructor_withValidArgs_createsCargoStatus() {
        assertNotNull(cargoStatus);
        assertEquals("TEST001", cargoStatus.getTrackingId());
    }

    @Test
    @DisplayName("getTrackingId returns tracking id")
    void getTrackingId_returnsTrackingId() {
        assertEquals("TEST001", cargoStatus.getTrackingId());
    }

    @Test
    @DisplayName("getDestination returns destination")
    void getDestination_returnsDestination() {
        assertEquals("New York", cargoStatus.getDestination());
    }

    @Test
    @DisplayName("getStatusText returns status text")
    void getStatusText_returnsStatusText() {
        assertEquals("In port", cargoStatus.getStatusText());
    }

    @Test
    @DisplayName("isMisdirected returns false when not misdirected")
    void isMisdirected_notMisdirected_returnsFalse() {
        assertFalse(cargoStatus.isMisdirected());
    }

    @Test
    @DisplayName("getEta returns eta")
    void getEta_returnsEta() {
        assertNotNull(cargoStatus.getEta());
    }

    @Test
    @DisplayName("getNextExpectedActivity returns next expected activity")
    void getNextExpectedActivity_returnsNextExpectedActivity() {
        assertEquals("Load in Hamburg", cargoStatus.getNextExpectedActivity());
    }

    @Test
    @DisplayName("getEvents returns events list")
    void getEvents_returnsEventsList() {
        List<TrackingEvents> result = cargoStatus.getEvents();
        assertNotNull(result);
        assertEquals(2, result.size());
    }

    @Test
    @DisplayName("getEvents returns unmodifiable list")
    void getEvents_returnsUnmodifiableList() {
        List<TrackingEvents> result = cargoStatus.getEvents();
        assertThrows(UnsupportedOperationException.class, () ->
                result.add(new TrackingEvents(true, "test", "test")));
    }
}
