package org.eclipse.pathfinder.api;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("TransitEdge Tests")
class TransitEdgeTest {

    private TransitEdge transitEdge;
    private LocalDateTime fromDate;
    private LocalDateTime toDate;

    @BeforeEach
    void setUp() {
        fromDate = LocalDateTime.of(2024, 1, 1, 10, 0);
        toDate = LocalDateTime.of(2024, 1, 3, 10, 0);
        transitEdge = new TransitEdge("V001", "SESTO", "DEHAM", fromDate, toDate);
    }

    @Test
    @DisplayName("Constructor creates TransitEdge with all fields")
    void constructor_withValidArgs_createsTransitEdge() {
        assertNotNull(transitEdge);
        assertEquals("V001", transitEdge.getVoyageNumber());
        assertEquals("SESTO", transitEdge.getFromUnLocode());
        assertEquals("DEHAM", transitEdge.getToUnLocode());
        assertEquals(fromDate, transitEdge.getFromDate());
        assertEquals(toDate, transitEdge.getToDate());
    }

    @Test
    @DisplayName("Default constructor creates TransitEdge")
    void defaultConstructor_createsTransitEdge() {
        TransitEdge edge = new TransitEdge();
        assertNotNull(edge);
    }

    @Test
    @DisplayName("setVoyageNumber updates voyage number")
    void setVoyageNumber_updatesVoyageNumber() {
        transitEdge.setVoyageNumber("V002");
        assertEquals("V002", transitEdge.getVoyageNumber());
    }

    @Test
    @DisplayName("setFromUnLocode updates from unLocode")
    void setFromUnLocode_updatesFromUnLocode() {
        transitEdge.setFromUnLocode("USNYC");
        assertEquals("USNYC", transitEdge.getFromUnLocode());
    }

    @Test
    @DisplayName("setToUnLocode updates to unLocode")
    void setToUnLocode_updatesToUnLocode() {
        transitEdge.setToUnLocode("USNYC");
        assertEquals("USNYC", transitEdge.getToUnLocode());
    }

    @Test
    @DisplayName("setFromDate updates from date")
    void setFromDate_updatesFromDate() {
        LocalDateTime newDate = LocalDateTime.of(2024, 2, 1, 10, 0);
        transitEdge.setFromDate(newDate);
        assertEquals(newDate, transitEdge.getFromDate());
    }

    @Test
    @DisplayName("setToDate updates to date")
    void setToDate_updatesToDate() {
        LocalDateTime newDate = LocalDateTime.of(2024, 2, 5, 10, 0);
        transitEdge.setToDate(newDate);
        assertEquals(newDate, transitEdge.getToDate());
    }

    @Test
    @DisplayName("toString returns non-null string with relevant info")
    void toString_returnsNonNullString() {
        String result = transitEdge.toString();
        assertNotNull(result);
        assertTrue(result.contains("TransitEdge"));
        assertTrue(result.contains("V001"));
        assertTrue(result.contains("SESTO"));
        assertTrue(result.contains("DEHAM"));
    }
}
