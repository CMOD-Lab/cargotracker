package org.eclipse.cargotracker.interfaces.booking.facade.dto;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("TrackingEvents DTO Tests")
class TrackingEventsTest {

    private TrackingEvents trackingEvents;

    @BeforeEach
    void setUp() {
        trackingEvents = new TrackingEvents(true, "Received in Stockholm", "1/1/2024 10:0 AM");
    }

    @Test
    @DisplayName("Constructor creates TrackingEvents with all fields")
    void constructor_withValidArgs_createsTrackingEvents() {
        assertNotNull(trackingEvents);
    }

    @Test
    @DisplayName("isExpected returns true when expected")
    void isExpected_whenExpected_returnsTrue() {
        assertTrue(trackingEvents.isExpected());
    }

    @Test
    @DisplayName("isExpected returns false when not expected")
    void isExpected_whenNotExpected_returnsFalse() {
        TrackingEvents unexpected = new TrackingEvents(false, "Unexpected event", "1/2/2024 10:0 AM");
        assertFalse(unexpected.isExpected());
    }

    @Test
    @DisplayName("getDescription returns description")
    void getDescription_returnsDescription() {
        assertEquals("Received in Stockholm", trackingEvents.getDescription());
    }

    @Test
    @DisplayName("getTime returns time")
    void getTime_returnsTime() {
        assertEquals("1/1/2024 10:0 AM", trackingEvents.getTime());
    }
}
