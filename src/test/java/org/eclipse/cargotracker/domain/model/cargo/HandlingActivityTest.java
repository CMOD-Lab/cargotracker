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

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("HandlingActivity Tests")
class HandlingActivityTest {

    private Location stockholm;
    private Location hamburg;
    private Voyage voyage;

    @BeforeEach
    void setUp() {
        stockholm = new Location(new UnLocode("SESTO"), "Stockholm");
        hamburg = new Location(new UnLocode("DEHAM"), "Hamburg");

        voyage = new Voyage.Builder(new VoyageNumber("V001"), stockholm)
                .addMovement(hamburg,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 3, 10, 0))
                .build();
    }

    @Test
    @DisplayName("Default constructor creates empty HandlingActivity")
    void defaultConstructor_createsEmptyHandlingActivity() {
        HandlingActivity activity = new HandlingActivity();
        assertNotNull(activity);
        assertTrue(activity.isEmpty());
    }

    @Test
    @DisplayName("Constructor with type and location creates HandlingActivity")
    void constructor_withTypeAndLocation_createsHandlingActivity() {
        HandlingActivity activity = new HandlingActivity(HandlingEvent.Type.RECEIVE, stockholm);
        assertNotNull(activity);
        assertEquals(HandlingEvent.Type.RECEIVE, activity.getType());
        assertEquals(stockholm, activity.getLocation());
        assertNull(activity.getVoyage());
    }

    @Test
    @DisplayName("Constructor with type, location and voyage creates HandlingActivity")
    void constructor_withTypeLocationAndVoyage_createsHandlingActivity() {
        HandlingActivity activity = new HandlingActivity(HandlingEvent.Type.LOAD, stockholm, voyage);
        assertNotNull(activity);
        assertEquals(HandlingEvent.Type.LOAD, activity.getType());
        assertEquals(stockholm, activity.getLocation());
        assertEquals(voyage, activity.getVoyage());
    }

    @Test
    @DisplayName("Constructor with null type throws NullPointerException")
    void constructor_withNullType_throwsException() {
        assertThrows(NullPointerException.class, () ->
                new HandlingActivity(null, stockholm));
    }

    @Test
    @DisplayName("Constructor with null location throws NullPointerException")
    void constructor_withNullLocation_throwsException() {
        assertThrows(NullPointerException.class, () ->
                new HandlingActivity(HandlingEvent.Type.RECEIVE, null));
    }

    @Test
    @DisplayName("Constructor with null voyage throws NullPointerException")
    void constructor_withNullVoyage_throwsException() {
        assertThrows(NullPointerException.class, () ->
                new HandlingActivity(HandlingEvent.Type.LOAD, stockholm, null));
    }

    @Test
    @DisplayName("isEmpty returns false when type is set")
    void isEmpty_withType_returnsFalse() {
        HandlingActivity activity = new HandlingActivity(HandlingEvent.Type.RECEIVE, stockholm);
        assertFalse(activity.isEmpty());
    }

    @Test
    @DisplayName("getType returns the type")
    void getType_returnsType() {
        HandlingActivity activity = new HandlingActivity(HandlingEvent.Type.CLAIM, stockholm);
        assertEquals(HandlingEvent.Type.CLAIM, activity.getType());
    }

    @Test
    @DisplayName("getLocation returns the location")
    void getLocation_returnsLocation() {
        HandlingActivity activity = new HandlingActivity(HandlingEvent.Type.RECEIVE, stockholm);
        assertEquals(stockholm, activity.getLocation());
    }

    @Test
    @DisplayName("getVoyage returns the voyage")
    void getVoyage_returnsVoyage() {
        HandlingActivity activity = new HandlingActivity(HandlingEvent.Type.LOAD, stockholm, voyage);
        assertEquals(voyage, activity.getVoyage());
    }

    @Test
    @DisplayName("equals returns true for same instance")
    void equals_sameInstance_returnsTrue() {
        HandlingActivity activity = new HandlingActivity(HandlingEvent.Type.RECEIVE, stockholm);
        assertEquals(activity, activity);
    }

    @Test
    @DisplayName("equals returns true for equal activities")
    void equals_equalActivities_returnsTrue() {
        HandlingActivity activity1 = new HandlingActivity(HandlingEvent.Type.RECEIVE, stockholm);
        HandlingActivity activity2 = new HandlingActivity(HandlingEvent.Type.RECEIVE, stockholm);
        assertEquals(activity1, activity2);
    }

    @Test
    @DisplayName("equals returns false for different type")
    void equals_differentType_returnsFalse() {
        HandlingActivity activity1 = new HandlingActivity(HandlingEvent.Type.RECEIVE, stockholm);
        HandlingActivity activity2 = new HandlingActivity(HandlingEvent.Type.CLAIM, stockholm);
        assertNotEquals(activity1, activity2);
    }

    @Test
    @DisplayName("equals returns false for null")
    void equals_null_returnsFalse() {
        HandlingActivity activity = new HandlingActivity(HandlingEvent.Type.RECEIVE, stockholm);
        assertNotEquals(null, activity);
    }

    @Test
    @DisplayName("hashCode is consistent for equal activities")
    void hashCode_equalActivities_sameHashCode() {
        HandlingActivity activity1 = new HandlingActivity(HandlingEvent.Type.RECEIVE, stockholm);
        HandlingActivity activity2 = new HandlingActivity(HandlingEvent.Type.RECEIVE, stockholm);
        assertEquals(activity1.hashCode(), activity2.hashCode());
    }
}
