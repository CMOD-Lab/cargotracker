package org.eclipse.cargotracker.domain.model.location;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("UnLocode Tests")
class UnLocodeTest {

    @Test
    @DisplayName("Constructor with valid code creates UnLocode")
    void constructor_withValidCode_createsUnLocode() {
        UnLocode unLocode = new UnLocode("SESTO");
        assertNotNull(unLocode);
        assertEquals("SESTO", unLocode.getIdString());
    }

    @Test
    @DisplayName("Constructor converts to uppercase")
    void constructor_convertsToUppercase() {
        UnLocode unLocode = new UnLocode("sesto");
        assertEquals("SESTO", unLocode.getIdString());
    }

    @Test
    @DisplayName("Constructor with null throws NullPointerException")
    void constructor_withNull_throwsException() {
        assertThrows(NullPointerException.class, () -> new UnLocode(null));
    }

    @Test
    @DisplayName("Constructor with invalid pattern throws IllegalArgumentException")
    void constructor_withInvalidPattern_throwsException() {
        assertThrows(IllegalArgumentException.class, () -> new UnLocode("INVALID_CODE"));
    }

    @Test
    @DisplayName("Constructor with too short code throws IllegalArgumentException")
    void constructor_withTooShortCode_throwsException() {
        assertThrows(IllegalArgumentException.class, () -> new UnLocode("AB"));
    }

    @Test
    @DisplayName("Default constructor creates UnLocode")
    void defaultConstructor_createsUnLocode() {
        UnLocode unLocode = new UnLocode();
        assertNotNull(unLocode);
    }

    @Test
    @DisplayName("getIdString returns the code")
    void getIdString_returnsCode() {
        UnLocode unLocode = new UnLocode("USNYC");
        assertEquals("USNYC", unLocode.getIdString());
    }

    @Test
    @DisplayName("equals returns true for same instance")
    void equals_sameInstance_returnsTrue() {
        UnLocode unLocode = new UnLocode("SESTO");
        assertEquals(unLocode, unLocode);
    }

    @Test
    @DisplayName("equals returns true for equal codes")
    void equals_equalCodes_returnsTrue() {
        UnLocode code1 = new UnLocode("SESTO");
        UnLocode code2 = new UnLocode("SESTO");
        assertEquals(code1, code2);
    }

    @Test
    @DisplayName("equals returns false for different codes")
    void equals_differentCodes_returnsFalse() {
        UnLocode code1 = new UnLocode("SESTO");
        UnLocode code2 = new UnLocode("USNYC");
        assertNotEquals(code1, code2);
    }

    @Test
    @DisplayName("equals returns false for null")
    void equals_null_returnsFalse() {
        UnLocode unLocode = new UnLocode("SESTO");
        assertNotEquals(null, unLocode);
    }

    @Test
    @DisplayName("hashCode is consistent for equal codes")
    void hashCode_equalCodes_sameHashCode() {
        UnLocode code1 = new UnLocode("SESTO");
        UnLocode code2 = new UnLocode("SESTO");
        assertEquals(code1.hashCode(), code2.hashCode());
    }

    @Test
    @DisplayName("toString returns the id string")
    void toString_returnsIdString() {
        UnLocode unLocode = new UnLocode("SESTO");
        assertEquals("SESTO", unLocode.toString());
    }

    @Test
    @DisplayName("sameValueAs returns true for equal codes")
    void sameValueAs_equalCodes_returnsTrue() {
        UnLocode code1 = new UnLocode("SESTO");
        UnLocode code2 = new UnLocode("SESTO");
        assertTrue(code1.sameValueAs(code2));
    }

    @Test
    @DisplayName("sameValueAs returns false for different codes")
    void sameValueAs_differentCodes_returnsFalse() {
        UnLocode code1 = new UnLocode("SESTO");
        UnLocode code2 = new UnLocode("USNYC");
        assertFalse(code1.sameValueAs(code2));
    }

    @Test
    @DisplayName("sameValueAs returns false for null")
    void sameValueAs_null_returnsFalse() {
        UnLocode unLocode = new UnLocode("SESTO");
        assertFalse(unLocode.sameValueAs(null));
    }

    @Test
    @DisplayName("Constructor with alphanumeric code (2-9) is valid")
    void constructor_withAlphanumericCode_isValid() {
        UnLocode unLocode = new UnLocode("SE2TO");
        assertNotNull(unLocode);
        assertEquals("SE2TO", unLocode.getIdString());
    }
}
