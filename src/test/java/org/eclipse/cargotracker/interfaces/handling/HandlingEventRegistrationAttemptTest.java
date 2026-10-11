package org.eclipse.cargotracker.interfaces.handling;

import org.eclipse.cargotracker.domain.model.cargo.TrackingId;
import org.eclipse.cargotracker.domain.model.handling.HandlingEvent;
import org.eclipse.cargotracker.domain.model.location.UnLocode;
import org.eclipse.cargotracker.domain.model.voyage.VoyageNumber;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("HandlingEventRegistrationAttempt Tests")
class HandlingEventRegistrationAttemptTest {

    private HandlingEventRegistrationAttempt attempt;
    private LocalDateTime registrationTime;
    private LocalDateTime completionTime;
    private TrackingId trackingId;
    private VoyageNumber voyageNumber;
    private UnLocode unLocode;

    @BeforeEach
    void setUp() {
        registrationTime = LocalDateTime.of(2024, 1, 1, 10, 0, 0);
        completionTime = LocalDateTime.of(2024, 1, 1, 9, 0, 0);
        trackingId = new TrackingId("TEST001");
        voyageNumber = new VoyageNumber("V001");
        unLocode = new UnLocode("SESTO");

        attempt = new HandlingEventRegistrationAttempt(
                registrationTime,
                completionTime,
                trackingId,
                voyageNumber,
                HandlingEvent.Type.LOAD,
                unLocode);
    }

    @Test
    @DisplayName("Constructor creates HandlingEventRegistrationAttempt with all fields")
    void constructor_withValidArgs_createsAttempt() {
        assertNotNull(attempt);
    }

    @Test
    @DisplayName("getTrackingId returns tracking id")
    void getTrackingId_returnsTrackingId() {
        assertEquals(trackingId, attempt.getTrackingId());
    }

    @Test
    @DisplayName("getVoyageNumber returns voyage number")
    void getVoyageNumber_returnsVoyageNumber() {
        assertEquals(voyageNumber, attempt.getVoyageNumber());
    }

    @Test
    @DisplayName("getType returns event type")
    void getType_returnsEventType() {
        assertEquals(HandlingEvent.Type.LOAD, attempt.getType());
    }

    @Test
    @DisplayName("getUnLocode returns unLocode")
    void getUnLocode_returnsUnLocode() {
        assertEquals(unLocode, attempt.getUnLocode());
    }

    @Test
    @DisplayName("getRegistrationTime returns registration time")
    void getRegistrationTime_returnsRegistrationTime() {
        assertEquals(registrationTime, attempt.getRegistrationTime());
    }

    @Test
    @DisplayName("getCompletionTime returns completion time")
    void getCompletionTime_returnsCompletionTime() {
        assertEquals(completionTime, attempt.getCompletionTime());
    }

    @Test
    @DisplayName("toString returns non-null string with relevant info")
    void toString_returnsNonNullString() {
        String result = attempt.toString();
        assertNotNull(result);
        assertTrue(result.contains("HandlingEventRegistrationAttempt"));
        assertTrue(result.contains("TEST001"));
    }

    @Test
    @DisplayName("Constructor with null voyageNumber creates attempt")
    void constructor_withNullVoyageNumber_createsAttempt() {
        HandlingEventRegistrationAttempt attemptNoVoyage = new HandlingEventRegistrationAttempt(
                registrationTime,
                completionTime,
                trackingId,
                null,
                HandlingEvent.Type.RECEIVE,
                unLocode);
        assertNotNull(attemptNoVoyage);
        assertNull(attemptNoVoyage.getVoyageNumber());
    }
}
