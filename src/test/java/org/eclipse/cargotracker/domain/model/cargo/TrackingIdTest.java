package org.eclipse.cargotracker.domain.model.cargo;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("TrackingId Tests")
class TrackingIdTest {

    @Test
    @DisplayName("Constructor with valid id creates TrackingId")
    void constructor_withValidId_createsTrackingId() {
        TrackingId trackingId = new TrackingId("ABC123");
        assertNotNull(trackingId);
        assertEquals("ABC123", trackingId.getIdString());
    }

    @Test
    @DisplayName("Default constructor creates TrackingId")
    void defaultConstructor_createsTrackingId() {
        TrackingId trackingId = new TrackingId();
        assertNotNull(trackingId);
    }

    @Test
    @DisplayName("Constructor with null id throws NullPointerException")
    void constructor_withNullId_throwsException() {
        assertThrows(NullPointerException.class, () -> new TrackingId(null));
    }

    @Test
    @DisplayName("getIdString returns the id")
    void getIdString_returnsId() {
        TrackingId trackingId = new TrackingId("XYZ789");
        assertEquals("XYZ789", trackingId.getIdString());
    }

    @Test
    @DisplayName("equals returns true for same instance")
    void equals_sameInstance_returnsTrue() {
        TrackingId trackingId = new TrackingId("ABC");
        assertEquals(trackingId, trackingId);
    }

    @Test
    @DisplayName("equals returns true for equal ids")
    void equals_equalIds_returnsTrue() {
        TrackingId id1 = new TrackingId("ABC");
        TrackingId id2 = new TrackingId("ABC");
        assertEquals(id1, id2);
    }

    @Test
    @DisplayName("equals returns false for different ids")
    void equals_differentIds_returnsFalse() {
        TrackingId id1 = new TrackingId("ABC");
        TrackingId id2 = new TrackingId("XYZ");
        assertNotEquals(id1, id2);
    }

    @Test
    @DisplayName("equals returns false for null")
    void equals_null_returnsFalse() {
        TrackingId trackingId = new TrackingId("ABC");
        assertNotEquals(null, trackingId);
    }

    @Test
    @DisplayName("equals returns false for different type")
    void equals_differentType_returnsFalse() {
        TrackingId trackingId = new TrackingId("ABC");
        assertNotEquals("ABC", trackingId);
    }

    @Test
    @DisplayName("hashCode is consistent for equal ids")
    void hashCode_equalIds_sameHashCode() {
        TrackingId id1 = new TrackingId("ABC");
        TrackingId id2 = new TrackingId("ABC");
        assertEquals(id1.hashCode(), id2.hashCode());
    }

    @Test
    @DisplayName("toString returns the id string")
    void toString_returnsIdString() {
        TrackingId trackingId = new TrackingId("TEST123");
        assertEquals("TEST123", trackingId.toString());
    }

    @Test
    @DisplayName("sameValueAs returns true for equal ids")
    void sameValueAs_equalIds_returnsTrue() {
        TrackingId id1 = new TrackingId("ABC");
        TrackingId id2 = new TrackingId("ABC");
        assertTrue(id1.sameValueAs(id2));
    }

    @Test
    @DisplayName("sameValueAs returns false for different ids")
    void sameValueAs_differentIds_returnsFalse() {
        TrackingId id1 = new TrackingId("ABC");
        TrackingId id2 = new TrackingId("XYZ");
        assertFalse(id1.sameValueAs(id2));
    }

    @Test
    @DisplayName("sameValueAs returns false for null")
    void sameValueAs_null_returnsFalse() {
        TrackingId trackingId = new TrackingId("ABC");
        assertFalse(trackingId.sameValueAs(null));
    }
}
