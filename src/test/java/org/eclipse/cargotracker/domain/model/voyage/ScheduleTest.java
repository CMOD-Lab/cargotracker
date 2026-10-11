package org.eclipse.cargotracker.domain.model.voyage;

import org.eclipse.cargotracker.domain.model.location.Location;
import org.eclipse.cargotracker.domain.model.location.UnLocode;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for Schedule - note that Schedule constructor is package-private,
 * so we test it indirectly through Voyage.Builder which is in the same package.
 */
@DisplayName("Schedule Tests")
class ScheduleTest {

    private Location stockholm;
    private Location hamburg;
    private Location newYork;
    private Voyage voyage;

    @BeforeEach
    void setUp() {
        stockholm = new Location(new UnLocode("SESTO"), "Stockholm");
        hamburg = new Location(new UnLocode("DEHAM"), "Hamburg");
        newYork = new Location(new UnLocode("USNYC"), "New York");

        voyage = new Voyage.Builder(new VoyageNumber("V001"), stockholm)
                .addMovement(hamburg,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 3, 10, 0))
                .addMovement(newYork,
                        LocalDateTime.of(2024, 1, 4, 10, 0),
                        LocalDateTime.of(2024, 1, 10, 10, 0))
                .build();
    }

    @Test
    @DisplayName("EMPTY schedule is not null")
    void emptySchedule_isNotNull() {
        assertNotNull(Schedule.EMPTY);
    }

    @Test
    @DisplayName("Schedule created via Voyage.Builder has carrier movements")
    void schedule_createdViaBuilder_hasCarrierMovements() {
        Schedule schedule = voyage.getSchedule();
        assertNotNull(schedule);
        assertEquals(2, schedule.getCarrierMovements().size());
    }

    @Test
    @DisplayName("getCarrierMovements returns unmodifiable list")
    void getCarrierMovements_returnsUnmodifiableList() {
        Schedule schedule = voyage.getSchedule();
        List<CarrierMovement> movements = schedule.getCarrierMovements();
        assertNotNull(movements);
        assertEquals(2, movements.size());
        assertThrows(UnsupportedOperationException.class, () ->
                movements.add(new CarrierMovement()));
    }

    @Test
    @DisplayName("Schedule equals returns true for same instance")
    void equals_sameInstance_returnsTrue() {
        Schedule schedule = voyage.getSchedule();
        assertEquals(schedule, schedule);
    }

    @Test
    @DisplayName("Schedule equals returns false for null")
    void equals_null_returnsFalse() {
        Schedule schedule = voyage.getSchedule();
        assertNotEquals(null, schedule);
    }

    @Test
    @DisplayName("Schedule hashCode is consistent")
    void hashCode_isConsistent() {
        Schedule schedule = voyage.getSchedule();
        assertEquals(schedule.hashCode(), schedule.hashCode());
    }

    @Test
    @DisplayName("Two schedules with same movements are equal")
    void twoSchedules_withSameMovements_areEqual() {
        Voyage voyage2 = new Voyage.Builder(new VoyageNumber("V002"), stockholm)
                .addMovement(hamburg,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 3, 10, 0))
                .addMovement(newYork,
                        LocalDateTime.of(2024, 1, 4, 10, 0),
                        LocalDateTime.of(2024, 1, 10, 10, 0))
                .build();

        assertEquals(voyage.getSchedule(), voyage2.getSchedule());
    }

    @Test
    @DisplayName("Two schedules with different movements are not equal")
    void twoSchedules_withDifferentMovements_areNotEqual() {
        Voyage voyage2 = new Voyage.Builder(new VoyageNumber("V002"), stockholm)
                .addMovement(hamburg,
                        LocalDateTime.of(2024, 1, 1, 10, 0),
                        LocalDateTime.of(2024, 1, 3, 10, 0))
                .build();

        assertNotEquals(voyage.getSchedule(), voyage2.getSchedule());
    }

    @Test
    @DisplayName("Default constructor creates empty Schedule")
    void defaultConstructor_createsEmptySchedule() {
        Schedule s = new Schedule();
        assertNotNull(s);
    }
}
