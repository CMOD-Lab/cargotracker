package org.eclipse.cargotracker.domain.model.voyage;

import org.eclipse.cargotracker.domain.model.location.Location;
import org.eclipse.cargotracker.domain.model.location.UnLocode;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.Collections;

import static org.junit.jupiter.api.Assertions.*;

@DisplayName("CarrierMovement Tests")
class CarrierMovementTest {

    private Location stockholm;
    private Location hamburg;
    private LocalDateTime departureTime;
    private LocalDateTime arrivalTime;
    private CarrierMovement movement;

    @BeforeEach
    void setUp() {
        stockholm = new Location(new UnLocode("SESTO"), "Stockholm");
        hamburg = new Location(new UnLocode("DEHAM"), "Hamburg");
        departureTime = LocalDateTime.of(2024, 1, 1, 10, 0, 0);
        arrivalTime = LocalDateTime.of(2024, 1, 3, 10, 0, 0);
        movement = new CarrierMovement(stockholm, hamburg, departureTime, arrivalTime);
    }

    @Test
    @DisplayName("Constructor creates CarrierMovement with all fields")
    void constructor_withValidArgs_createsCarrierMovement() {
        assertNotNull(movement);
        assertEquals(stockholm, movement.getDepartureLocation());
        assertEquals(hamburg, movement.getArrivalLocation());
        assertEquals(departureTime, movement.getDepartureTime());
        assertEquals(arrivalTime, movement.getArrivalTime());
    }

    @Test
    @DisplayName("Default constructor creates CarrierMovement")
    void defaultConstructor_createsCarrierMovement() {
        CarrierMovement cm = new CarrierMovement();
        assertNotNull(cm);
    }

    @Test
    @DisplayName("Constructor with null departure location throws exception")
    void constructor_withNullDepartureLocation_throwsException() {
        assertThrows(Exception.class, () ->
                new CarrierMovement(null, hamburg, departureTime, arrivalTime));
    }

    @Test
    @DisplayName("Constructor with null arrival location throws exception")
    void constructor_withNullArrivalLocation_throwsException() {
        assertThrows(Exception.class, () ->
                new CarrierMovement(stockholm, null, departureTime, arrivalTime));
    }

    @Test
    @DisplayName("Constructor with null departure time throws exception")
    void constructor_withNullDepartureTime_throwsException() {
        assertThrows(Exception.class, () ->
                new CarrierMovement(stockholm, hamburg, null, arrivalTime));
    }

    @Test
    @DisplayName("Constructor with null arrival time throws exception")
    void constructor_withNullArrivalTime_throwsException() {
        assertThrows(Exception.class, () ->
                new CarrierMovement(stockholm, hamburg, departureTime, null));
    }

    @Test
    @DisplayName("NONE carrier movement is not null")
    void noneCarrierMovement_isNotNull() {
        assertNotNull(CarrierMovement.NONE);
    }

    @Test
    @DisplayName("getDepartureLocation returns departure location")
    void getDepartureLocation_returnsDepartureLocation() {
        assertEquals(stockholm, movement.getDepartureLocation());
    }

    @Test
    @DisplayName("getArrivalLocation returns arrival location")
    void getArrivalLocation_returnsArrivalLocation() {
        assertEquals(hamburg, movement.getArrivalLocation());
    }

    @Test
    @DisplayName("getDepartureTime returns departure time")
    void getDepartureTime_returnsDepartureTime() {
        assertEquals(departureTime, movement.getDepartureTime());
    }

    @Test
    @DisplayName("getArrivalTime returns arrival time")
    void getArrivalTime_returnsArrivalTime() {
        assertEquals(arrivalTime, movement.getArrivalTime());
    }

    @Test
    @DisplayName("equals returns true for same instance")
    void equals_sameInstance_returnsTrue() {
        assertEquals(movement, movement);
    }

    @Test
    @DisplayName("equals returns true for equal movements")
    void equals_equalMovements_returnsTrue() {
        CarrierMovement movement2 = new CarrierMovement(stockholm, hamburg, departureTime, arrivalTime);
        assertEquals(movement, movement2);
    }

    @Test
    @DisplayName("equals returns false for different departure location")
    void equals_differentDepartureLocation_returnsFalse() {
        Location nyc = new Location(new UnLocode("USNYC"), "New York");
        CarrierMovement movement2 = new CarrierMovement(nyc, hamburg, departureTime, arrivalTime);
        assertNotEquals(movement, movement2);
    }

    @Test
    @DisplayName("equals returns false for null")
    void equals_null_returnsFalse() {
        assertNotEquals(null, movement);
    }

    @Test
    @DisplayName("hashCode is consistent for equal movements")
    void hashCode_equalMovements_sameHashCode() {
        CarrierMovement movement2 = new CarrierMovement(stockholm, hamburg, departureTime, arrivalTime);
        assertEquals(movement.hashCode(), movement2.hashCode());
    }
}
