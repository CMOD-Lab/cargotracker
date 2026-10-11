package org.eclipse.cargotracker.domain.model.location;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Location Tests")
class LocationTest {

    private UnLocode stockholmCode;
    private UnLocode nycCode;
    private Location stockholm;
    private Location nyc;

    @BeforeEach
    void setUp() {
        stockholmCode = new UnLocode("SESTO");
        nycCode = new UnLocode("USNYC");
        stockholm = new Location(stockholmCode, "Stockholm");
        nyc = new Location(nycCode, "New York");
    }

    @Test
    @DisplayName("Constructor creates Location with unLocode and name")
    void constructor_withValidArgs_createsLocation() {
        assertNotNull(stockholm);
        assertEquals(stockholmCode, stockholm.getUnLocode());
        assertEquals("Stockholm", stockholm.getName());
    }

    @Test
    @DisplayName("Default constructor creates Location")
    void defaultConstructor_createsLocation() {
        Location location = new Location();
        assertNotNull(location);
    }

    @Test
    @DisplayName("Constructor with null unLocode throws NullPointerException")
    void constructor_withNullUnLocode_throwsException() {
        assertThrows(NullPointerException.class, () -> new Location(null, "Stockholm"));
    }

    @Test
    @DisplayName("Constructor with null name throws NullPointerException")
    void constructor_withNullName_throwsException() {
        assertThrows(NullPointerException.class, () -> new Location(stockholmCode, null));
    }

    @Test
    @DisplayName("getUnLocode returns the unLocode")
    void getUnLocode_returnsUnLocode() {
        assertEquals(stockholmCode, stockholm.getUnLocode());
    }

    @Test
    @DisplayName("getName returns the name")
    void getName_returnsName() {
        assertEquals("Stockholm", stockholm.getName());
    }

    @Test
    @DisplayName("UNKNOWN location is not null")
    void unknownLocation_isNotNull() {
        assertNotNull(Location.UNKNOWN);
    }

    @Test
    @DisplayName("UNKNOWN location has XXXXX code")
    void unknownLocation_hasXXXXXCode() {
        assertEquals("XXXXX", Location.UNKNOWN.getUnLocode().getIdString());
    }

    @Test
    @DisplayName("equals returns true for same instance")
    void equals_sameInstance_returnsTrue() {
        assertEquals(stockholm, stockholm);
    }

    @Test
    @DisplayName("equals returns true for same unLocode")
    void equals_sameUnLocode_returnsTrue() {
        Location stockholm2 = new Location(new UnLocode("SESTO"), "Stockholm");
        assertEquals(stockholm, stockholm2);
    }

    @Test
    @DisplayName("equals returns false for different unLocode")
    void equals_differentUnLocode_returnsFalse() {
        assertNotEquals(stockholm, nyc);
    }

    @Test
    @DisplayName("equals returns false for null")
    void equals_null_returnsFalse() {
        assertNotEquals(null, stockholm);
    }

    @Test
    @DisplayName("equals returns false for different type")
    void equals_differentType_returnsFalse() {
        assertNotEquals("Stockholm", stockholm);
    }

    @Test
    @DisplayName("hashCode is consistent for equal locations")
    void hashCode_equalLocations_sameHashCode() {
        Location stockholm2 = new Location(new UnLocode("SESTO"), "Stockholm");
        assertEquals(stockholm.hashCode(), stockholm2.hashCode());
    }

    @Test
    @DisplayName("sameIdentityAs returns true for same unLocode")
    void sameIdentityAs_sameUnLocode_returnsTrue() {
        Location stockholm2 = new Location(new UnLocode("SESTO"), "Stockholm");
        assertTrue(stockholm.sameIdentityAs(stockholm2));
    }

    @Test
    @DisplayName("sameIdentityAs returns false for different unLocode")
    void sameIdentityAs_differentUnLocode_returnsFalse() {
        assertFalse(stockholm.sameIdentityAs(nyc));
    }

    @Test
    @DisplayName("toString returns name and unLocode")
    void toString_returnsNameAndUnLocode() {
        String result = stockholm.toString();
        assertTrue(result.contains("Stockholm"));
        assertTrue(result.contains("SESTO"));
    }
}
