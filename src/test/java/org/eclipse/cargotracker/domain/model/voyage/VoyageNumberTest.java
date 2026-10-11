package org.eclipse.cargotracker.domain.model.voyage;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("VoyageNumber Tests")
class VoyageNumberTest {

    @Test
    @DisplayName("Constructor with valid number creates VoyageNumber")
    void constructor_withValidNumber_createsVoyageNumber() {
        VoyageNumber voyageNumber = new VoyageNumber("V001");
        assertNotNull(voyageNumber);
        assertEquals("V001", voyageNumber.getIdString());
    }

    @Test
    @DisplayName("Default constructor creates VoyageNumber")
    void defaultConstructor_createsVoyageNumber() {
        VoyageNumber voyageNumber = new VoyageNumber();
        assertNotNull(voyageNumber);
    }

    @Test
    @DisplayName("Constructor with null throws NullPointerException")
    void constructor_withNull_throwsException() {
        assertThrows(NullPointerException.class, () -> new VoyageNumber(null));
    }

    @Test
    @DisplayName("getIdString returns the number")
    void getIdString_returnsNumber() {
        VoyageNumber voyageNumber = new VoyageNumber("V100");
        assertEquals("V100", voyageNumber.getIdString());
    }

    @Test
    @DisplayName("toString returns the number")
    void toString_returnsNumber() {
        VoyageNumber voyageNumber = new VoyageNumber("V100");
        assertEquals("V100", voyageNumber.toString());
    }

    @Test
    @DisplayName("equals returns true for same instance")
    void equals_sameInstance_returnsTrue() {
        VoyageNumber voyageNumber = new VoyageNumber("V001");
        assertEquals(voyageNumber, voyageNumber);
    }

    @Test
    @DisplayName("equals returns true for equal numbers")
    void equals_equalNumbers_returnsTrue() {
        VoyageNumber v1 = new VoyageNumber("V001");
        VoyageNumber v2 = new VoyageNumber("V001");
        assertEquals(v1, v2);
    }

    @Test
    @DisplayName("equals returns false for different numbers")
    void equals_differentNumbers_returnsFalse() {
        VoyageNumber v1 = new VoyageNumber("V001");
        VoyageNumber v2 = new VoyageNumber("V002");
        assertNotEquals(v1, v2);
    }

    @Test
    @DisplayName("equals returns false for null")
    void equals_null_returnsFalse() {
        VoyageNumber voyageNumber = new VoyageNumber("V001");
        assertNotEquals(null, voyageNumber);
    }

    @Test
    @DisplayName("hashCode is consistent for equal numbers")
    void hashCode_equalNumbers_sameHashCode() {
        VoyageNumber v1 = new VoyageNumber("V001");
        VoyageNumber v2 = new VoyageNumber("V001");
        assertEquals(v1.hashCode(), v2.hashCode());
    }

    @Test
    @DisplayName("sameValueAs returns true for equal numbers")
    void sameValueAs_equalNumbers_returnsTrue() {
        VoyageNumber v1 = new VoyageNumber("V001");
        VoyageNumber v2 = new VoyageNumber("V001");
        assertTrue(v1.sameValueAs(v2));
    }

    @Test
    @DisplayName("sameValueAs returns false for different numbers")
    void sameValueAs_differentNumbers_returnsFalse() {
        VoyageNumber v1 = new VoyageNumber("V001");
        VoyageNumber v2 = new VoyageNumber("V002");
        assertFalse(v1.sameValueAs(v2));
    }

    @Test
    @DisplayName("sameValueAs returns false for null")
    void sameValueAs_null_returnsFalse() {
        VoyageNumber voyageNumber = new VoyageNumber("V001");
        assertFalse(voyageNumber.sameValueAs(null));
    }
}
