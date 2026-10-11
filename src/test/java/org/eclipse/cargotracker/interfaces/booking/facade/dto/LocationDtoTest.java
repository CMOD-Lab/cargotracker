package org.eclipse.cargotracker.interfaces.booking.facade.dto;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Location DTO Tests")
class LocationDtoTest {

    private Location location;

    @BeforeEach
    void setUp() {
        location = new Location("SESTO", "Stockholm");
    }

    @Test
    @DisplayName("Constructor creates Location with unLocode and name")
    void constructor_withValidArgs_createsLocation() {
        assertNotNull(location);
        assertEquals("SESTO", location.getUnLocode());
        assertEquals("Stockholm", location.getName());
    }

    @Test
    @DisplayName("getUnLocode returns unLocode")
    void getUnLocode_returnsUnLocode() {
        assertEquals("SESTO", location.getUnLocode());
    }

    @Test
    @DisplayName("getName returns name")
    void getName_returnsName() {
        assertEquals("Stockholm", location.getName());
    }

    @Test
    @DisplayName("toString returns name and unLocode")
    void toString_returnsNameAndUnLocode() {
        String result = location.toString();
        assertNotNull(result);
        assertTrue(result.contains("Stockholm"));
        assertTrue(result.contains("SESTO"));
    }
}
