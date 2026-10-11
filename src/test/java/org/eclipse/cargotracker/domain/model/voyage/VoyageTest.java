package org.eclipse.cargotracker.domain.model.voyage;

import org.eclipse.cargotracker.domain.model.location.Location;
import org.eclipse.cargotracker.domain.model.location.UnLocode;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("Voyage Tests")
class VoyageTest {

    private Location stockholm;
    private Location hamburg;
    private Location newYork;
    private VoyageNumber voyageNumber;
    private Voyage voyage;

    @BeforeEach
    void setUp() {
        stockholm = new Location(new UnLocode("SESTO"), "Stockholm");
        hamburg = new Location(new UnLocode("DEHAM"), "Hamburg");
        newYork = new Location(new UnLocode("USNYC"), "New York");

        voyageNumber = new VoyageNumber("V001");
        voyage = new Voyage.Builder(voyageNumber, stockholm)
                .addMovement(hamburg,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 3, 10, 0))
                .addMovement(newYork,
                        LocalDateTime.of(2024, 1, 4, 10, 0),
                        LocalDateTime.of(2024, 1, 10, 10, 0))
                .build();
    }

    @Test
    @DisplayName("Builder creates Voyage with voyageNumber and schedule")
    void builder_createsVoyageWithVoyageNumberAndSchedule() {
        assertNotNull(voyage);
        assertEquals(voyageNumber, voyage.getVoyageNumber());
        assertNotNull(voyage.getSchedule());
    }

    @Test
    @DisplayName("Default constructor creates Voyage")
    void defaultConstructor_createsVoyage() {
        Voyage v = new Voyage();
        assertNotNull(v);
    }

    @Test
    @DisplayName("NONE voyage is not null")
    void noneVoyage_isNotNull() {
        assertNotNull(Voyage.NONE);
    }

    @Test
    @DisplayName("NONE voyage has empty voyage number")
    void noneVoyage_hasEmptyVoyageNumber() {
        assertEquals("", Voyage.NONE.getVoyageNumber().getIdString());
    }

    @Test
    @DisplayName("getVoyageNumber returns the voyage number")
    void getVoyageNumber_returnsVoyageNumber() {
        assertEquals(voyageNumber, voyage.getVoyageNumber());
    }

    @Test
    @DisplayName("getSchedule returns the schedule")
    void getSchedule_returnsSchedule() {
        assertNotNull(voyage.getSchedule());
        assertEquals(2, voyage.getSchedule().getCarrierMovements().size());
    }

    @Test
    @DisplayName("equals returns true for same instance")
    void equals_sameInstance_returnsTrue() {
        assertEquals(voyage, voyage);
    }

    @Test
    @DisplayName("equals returns true for same voyage number")
    void equals_sameVoyageNumber_returnsTrue() {
        Voyage voyage2 = new Voyage.Builder(new VoyageNumber("V001"), stockholm)
                .addMovement(hamburg,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 3, 10, 0))
                .build();
        assertEquals(voyage, voyage2);
    }

    @Test
    @DisplayName("equals returns false for different voyage number")
    void equals_differentVoyageNumber_returnsFalse() {
        Voyage voyage2 = new Voyage.Builder(new VoyageNumber("V002"), stockholm)
                .addMovement(hamburg,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 3, 10, 0))
                .build();
        assertNotEquals(voyage, voyage2);
    }

    @Test
    @DisplayName("equals returns false for null")
    void equals_null_returnsFalse() {
        assertNotEquals(null, voyage);
    }

    @Test
    @DisplayName("hashCode is consistent for equal voyages")
    void hashCode_equalVoyages_sameHashCode() {
        Voyage voyage2 = new Voyage.Builder(new VoyageNumber("V001"), stockholm)
                .addMovement(hamburg,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 3, 10, 0))
                .build();
        assertEquals(voyage.hashCode(), voyage2.hashCode());
    }

    @Test
    @DisplayName("sameIdentityAs returns true for same voyage number")
    void sameIdentityAs_sameVoyageNumber_returnsTrue() {
        Voyage voyage2 = new Voyage.Builder(new VoyageNumber("V001"), stockholm)
                .addMovement(hamburg,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 3, 10, 0))
                .build();
        assertTrue(voyage.sameIdentityAs(voyage2));
    }

    @Test
    @DisplayName("sameIdentityAs returns false for different voyage number")
    void sameIdentityAs_differentVoyageNumber_returnsFalse() {
        Voyage voyage2 = new Voyage.Builder(new VoyageNumber("V002"), stockholm)
                .addMovement(hamburg,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 3, 10, 0))
                .build();
        assertFalse(voyage.sameIdentityAs(voyage2));
    }

    @Test
    @DisplayName("toString contains voyage number")
    void toString_containsVoyageNumber() {
        String result = voyage.toString();
        assertTrue(result.contains("V001"));
    }

    @Test
    @DisplayName("Builder creates Voyage with movements")
    void builder_createsVoyageWithMovements() {
        LocalDateTime dep = LocalDateTime.of(2024, 1, 1, 10, 0);
        LocalDateTime arr = LocalDateTime.of(2024, 1, 3, 10, 0);

        Voyage built = new Voyage.Builder(new VoyageNumber("V999"), stockholm)
                .addMovement(hamburg, dep, arr)
                .build();

        assertNotNull(built);
        assertEquals("V999", built.getVoyageNumber().getIdString());
    }

    @Test
    @DisplayName("Builder with null voyageNumber throws NullPointerException")
    void builder_withNullVoyageNumber_throwsException() {
        assertThrows(NullPointerException.class, () -> new Voyage.Builder(null, stockholm));
    }

    @Test
    @DisplayName("Builder with null departure location throws NullPointerException")
    void builder_withNullDepartureLocation_throwsException() {
        assertThrows(NullPointerException.class, () -> new Voyage.Builder(voyageNumber, null));
    }
}
