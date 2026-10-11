package org.eclipse.cargotracker.domain.model.cargo;

import org.eclipse.cargotracker.domain.model.location.Location;
import org.eclipse.cargotracker.domain.model.location.UnLocode;
import org.eclipse.cargotracker.domain.model.voyage.Voyage;
import org.eclipse.cargotracker.domain.model.voyage.VoyageNumber;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.time.LocalDateTime;
import java.util.Arrays;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Leg Tests")
class LegTest {

    private Location stockholm;
    private Location hamburg;
    private Voyage voyage;
    private LocalDateTime loadTime;
    private LocalDateTime unloadTime;
    private Leg leg;

    @BeforeEach
    void setUp() {
        stockholm = new Location(new UnLocode("SESTO"), "Stockholm");
        hamburg = new Location(new UnLocode("DEHAM"), "Hamburg");

        voyage = new Voyage.Builder(new VoyageNumber("V001"), stockholm)
                .addMovement(hamburg,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 3, 10, 0))
                .build();

        loadTime = LocalDateTime.of(2024, 1, 1, 10, 0, 0);
        unloadTime = LocalDateTime.of(2024, 1, 3, 10, 0, 0);
        leg = new Leg(voyage, stockholm, hamburg, loadTime, unloadTime);
    }

    @Test
    @DisplayName("Constructor creates Leg with all fields")
    void constructor_withValidArgs_createsLeg() {
        assertNotNull(leg);
        assertEquals(voyage, leg.getVoyage());
        assertEquals(stockholm, leg.getLoadLocation());
        assertEquals(hamburg, leg.getUnloadLocation());
        assertEquals(loadTime, leg.getLoadTime());
        assertEquals(unloadTime, leg.getUnloadTime());
    }

    @Test
    @DisplayName("Default constructor creates Leg")
    void defaultConstructor_createsLeg() {
        Leg l = new Leg();
        assertNotNull(l);
    }

    @Test
    @DisplayName("Constructor with null voyage throws exception")
    void constructor_withNullVoyage_throwsException() {
        assertThrows(Exception.class, () ->
                new Leg(null, stockholm, hamburg, loadTime, unloadTime));
    }

    @Test
    @DisplayName("Constructor with null load location throws exception")
    void constructor_withNullLoadLocation_throwsException() {
        assertThrows(Exception.class, () ->
                new Leg(voyage, null, hamburg, loadTime, unloadTime));
    }

    @Test
    @DisplayName("Constructor with null unload location throws exception")
    void constructor_withNullUnloadLocation_throwsException() {
        assertThrows(Exception.class, () ->
                new Leg(voyage, stockholm, null, loadTime, unloadTime));
    }

    @Test
    @DisplayName("Constructor with null load time throws exception")
    void constructor_withNullLoadTime_throwsException() {
        assertThrows(Exception.class, () ->
                new Leg(voyage, stockholm, hamburg, null, unloadTime));
    }

    @Test
    @DisplayName("Constructor with null unload time throws exception")
    void constructor_withNullUnloadTime_throwsException() {
        assertThrows(Exception.class, () ->
                new Leg(voyage, stockholm, hamburg, loadTime, null));
    }

    @Test
    @DisplayName("getVoyage returns the voyage")
    void getVoyage_returnsVoyage() {
        assertEquals(voyage, leg.getVoyage());
    }

    @Test
    @DisplayName("getLoadLocation returns the load location")
    void getLoadLocation_returnsLoadLocation() {
        assertEquals(stockholm, leg.getLoadLocation());
    }

    @Test
    @DisplayName("getUnloadLocation returns the unload location")
    void getUnloadLocation_returnsUnloadLocation() {
        assertEquals(hamburg, leg.getUnloadLocation());
    }

    @Test
    @DisplayName("getLoadTime returns the load time")
    void getLoadTime_returnsLoadTime() {
        assertEquals(loadTime, leg.getLoadTime());
    }

    @Test
    @DisplayName("getUnloadTime returns the unload time")
    void getUnloadTime_returnsUnloadTime() {
        assertEquals(unloadTime, leg.getUnloadTime());
    }

    @Test
    @DisplayName("equals returns true for same instance")
    void equals_sameInstance_returnsTrue() {
        assertEquals(leg, leg);
    }

    @Test
    @DisplayName("equals returns true for equal legs")
    void equals_equalLegs_returnsTrue() {
        Leg leg2 = new Leg(voyage, stockholm, hamburg, loadTime, unloadTime);
        assertEquals(leg, leg2);
    }

    @Test
    @DisplayName("equals returns false for different voyage")
    void equals_differentVoyage_returnsFalse() {
        Voyage voyage2 = new Voyage.Builder(new VoyageNumber("V002"), stockholm)
                .addMovement(hamburg,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 3, 10, 0))
                .build();
        Leg leg2 = new Leg(voyage2, stockholm, hamburg, loadTime, unloadTime);
        assertNotEquals(leg, leg2);
    }

    @Test
    @DisplayName("equals returns false for null")
    void equals_null_returnsFalse() {
        assertNotEquals(null, leg);
    }

    @Test
    @DisplayName("hashCode is consistent for equal legs")
    void hashCode_equalLegs_sameHashCode() {
        Leg leg2 = new Leg(voyage, stockholm, hamburg, loadTime, unloadTime);
        assertEquals(leg.hashCode(), leg2.hashCode());
    }

    @Test
    @DisplayName("toString contains relevant information")
    void toString_containsRelevantInfo() {
        String result = leg.toString();
        assertNotNull(result);
        assertTrue(result.contains("Leg"));
    }
}
