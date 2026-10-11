package org.eclipse.cargotracker.interfaces.booking.facade.dto;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Leg DTO Tests")
class LegDtoTest {

    private Location from;
    private Location to;
    private Leg leg;

    @BeforeEach
    void setUp() {
        from = new Location("SESTO", "Stockholm");
        to = new Location("DEHAM", "Hamburg");
        leg = new Leg("V001", from, to,
                LocalDateTime.of(2024, 1, 1, 10, 0),
                LocalDateTime.of(2024, 1, 3, 10, 0));
    }

    @Test
    @DisplayName("Constructor creates Leg with all fields")
    void constructor_withValidArgs_createsLeg() {
        assertNotNull(leg);
        assertEquals("V001", leg.getVoyageNumber());
    }

    @Test
    @DisplayName("getVoyageNumber returns voyage number")
    void getVoyageNumber_returnsVoyageNumber() {
        assertEquals("V001", leg.getVoyageNumber());
    }

    @Test
    @DisplayName("getFrom returns from location as string")
    void getFrom_returnsFromString() {
        assertNotNull(leg.getFrom());
        assertTrue(leg.getFrom().contains("Stockholm"));
    }

    @Test
    @DisplayName("getFromUnLocode returns from unlocode")
    void getFromUnLocode_returnsFromUnLocode() {
        assertEquals("SESTO", leg.getFromUnLocode());
    }

    @Test
    @DisplayName("getFromName returns from name")
    void getFromName_returnsFromName() {
        assertEquals("Stockholm", leg.getFromName());
    }

    @Test
    @DisplayName("getTo returns to location as string")
    void getTo_returnsToString() {
        assertNotNull(leg.getTo());
        assertTrue(leg.getTo().contains("Hamburg"));
    }

    @Test
    @DisplayName("getToName returns to name")
    void getToName_returnsToName() {
        assertEquals("Hamburg", leg.getToName());
    }

    @Test
    @DisplayName("getToUnLocode returns to unlocode")
    void getToUnLocode_returnsToUnLocode() {
        assertEquals("DEHAM", leg.getToUnLocode());
    }

    @Test
    @DisplayName("getLoadTime returns formatted load time")
    void getLoadTime_returnsFormattedLoadTime() {
        assertNotNull(leg.getLoadTime());
        assertTrue(leg.getLoadTime().contains("1/1/2024"));
    }

    @Test
    @DisplayName("getUnloadTime returns formatted unload time")
    void getUnloadTime_returnsFormattedUnloadTime() {
        assertNotNull(leg.getUnloadTime());
        assertTrue(leg.getUnloadTime().contains("1/3/2024"));
    }

    @Test
    @DisplayName("toString returns non-null string")
    void toString_returnsNonNullString() {
        String result = leg.toString();
        assertNotNull(result);
        assertTrue(result.contains("V001"));
    }
}
